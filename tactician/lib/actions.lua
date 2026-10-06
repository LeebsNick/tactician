-- Turns a rule's do into one concrete action for a subject, or says why it cannot fire right
-- now: the spell, ability, weapon skill or item by name, checked against what is learned,
-- the job levels, MP, TP, recasts, bag contents and what the action can be aimed at.
local catalog = require('lib.catalog');
local vocab   = require('lib.vocab');

local M = {};

-- target flag bits in the client DATs
M.SELF, M.PLAYER, M.PARTY, M.ALLY, M.NPC, M.ENEMY, M.CORPSE = 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x80;

M.JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG',
           'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN' };

local function has(flags, bits)
    return flags ~= nil and bit.band(flags, bits) ~= 0;
end

local function describe(subject)
    if subject.kind == 'self' then return 'me'; end
    if subject.kind == 'member' then return subject.dead and 'dead party member' or 'party member'; end
    if subject.kind == 'pet' then return 'pet'; end
    return 'the target';
end

-- Where the action lands: on the subject when its flags allow, on me for a self-only action,
-- otherwise on the target for an enemy action. nil plus a reason when nowhere.
local function aim(flags, subject, snap)
    local kind = subject.kind;
    if kind == 'self' and has(flags, M.SELF + M.PLAYER + M.PARTY + M.ALLY) then return '<me>'; end
    if kind == 'member' and not subject.dead and has(flags, M.PLAYER + M.PARTY + M.ALLY) then return subject.token; end
    if kind == 'member' and subject.dead and has(flags, M.CORPSE) then return subject.token; end
    if kind == 'pet' and has(flags, M.PLAYER + M.PARTY + M.ALLY + M.NPC) then return '<pet>'; end
    if kind == 'enemy' and has(flags, M.ENEMY) then return '<t>'; end
    if kind ~= 'self' and has(flags, M.SELF) and not has(flags, M.PLAYER + M.PARTY + M.ALLY) then return '<me>'; end
    if has(flags, M.ENEMY) then
        if snap.target then return '<t>'; end
        return nil, 'no target';
    end
    return nil, 'cannot target ' .. describe(subject);
end

-- the level the spell wants from the job that could cast it, or nil when castable now
local function level_gap(spell, me)
    local main, sub = spell.levels[me.job], spell.levels[me.sub];
    if main and main > 0 and me.level >= main then return nil; end
    if sub and sub > 0 and me.sublevel and me.sublevel >= sub then return nil; end
    if main and main > 0 then return ('needs %s %d'):format(M.JOBS[me.job] or '?', main); end
    if sub and sub > 0 then return ('needs %s %d'):format(M.JOBS[me.sub] or '?', sub); end
    return ('not for %s/%s'):format(M.JOBS[me.job] or '?', M.JOBS[me.sub] or '?');
end

local function spell_action(spell, subject, snap)
    local known = snap.known and snap.known.spell or {};
    if not known[spell.id] then return nil, 'not learned'; end
    local gap = level_gap(spell, snap.me);
    if gap then return nil, gap; end
    if (snap.me.mp or 0) < (spell.mp or 0) then return nil, 'not enough MP'; end
    local left = snap.recast.spell[spell.id];
    if left and left > 0 then return nil, ('recast %ds'):format(math.ceil(left)); end
    local token, why = aim(spell.targets, subject, snap);
    if not token then return nil, why; end
    return { kind = 'ma', id = spell.id, name = spell.name, token = token, cast = spell.cast };
end

local function ability_action(ability, subject, snap)
    local known = snap.known and snap.known.ability or {};
    if not known[ability.id] then return nil, 'not learned'; end
    local left = snap.recast.ability[ability.timer];
    if left and left > 0 then return nil, ('recast %ds'):format(math.ceil(left)); end
    if (ability.tp or 0) > 0 and (snap.me.tp or 0) < ability.tp then return nil, 'not enough TP'; end
    local token, why = aim(ability.targets, subject, snap);
    if not token then return nil, why; end
    return { kind = 'ja', id = ability.id, name = ability.name, token = token };
end

-- the highest tier that resolves; the reason comes from the highest tier that is learned
local function best(fam, resolve, subject, snap)
    local reason = 'not learned';
    for i = #fam.tiers, 1, -1 do
        local a, why = resolve(fam.tiers[i], subject, snap);
        if a then return a; end
        if why ~= 'not learned' and reason == 'not learned' then reason = why; end
    end
    return nil, reason;
end

-- Anything aimed at the monster waits until I have engaged it myself: the line between an
-- attended helper and a bot is whether a human pulled.
local function engaged_only(a, why, snap)
    if a and a.token == '<t>' and snap.me.status ~= 'engaged' then return nil, 'not engaged'; end
    return a, why;
end

local resolve_any;

function M.resolve(act, subject, cat, snap)
    local a, why = resolve_any(act, subject, cat, snap);
    return engaged_only(a, why, snap);
end

resolve_any = function(act, subject, cat, snap)
    local r = act.reaction;
    if r == 'ma' then
        if act.selector == 'highest' then
            local fam = catalog.family(cat, act.arg, 'spell');
            if not fam then return nil, 'unknown family'; end
            return best(fam, spell_action, subject, snap);
        end
        local spell = catalog.spell(cat, act.arg);
        if not spell then return nil, 'unknown spell'; end
        return spell_action(spell, subject, snap);
    end
    if r == 'ja' then
        if act.selector == 'highest' then
            local fam = catalog.family(cat, act.arg, 'ability');
            if not fam then return nil, 'unknown family'; end
            return best(fam, ability_action, subject, snap);
        end
        local ability = catalog.ability(cat, act.arg);
        if not ability then return nil, 'unknown ability'; end
        return ability_action(ability, subject, snap);
    end
    if r == 'ws' then
        local ws = catalog.weaponskill(cat, act.arg);
        if not ws then return nil, 'unknown weapon skill'; end
        local known = snap.known and snap.known.ws or {};
        if not known[ws.id] then return nil, 'not learned'; end
        if (snap.me.tp or 0) < 1000 then return nil, 'not enough TP'; end
        if not snap.target then return nil, 'no target'; end
        return { kind = 'ws', id = ws.id, name = ws.name, token = '<t>' };
    end
    if r == 'rattack' then
        if not snap.target then return nil, 'no target'; end
        return { kind = 'rattack', token = '<t>' };
    end
    if r == 'item' then
        local item = catalog.item(cat, act.arg);
        if not item then return nil, 'unknown item'; end
        if (snap.items[item.id] or 0) <= 0 then return nil, 'none in bags'; end
        return { kind = 'item', id = item.id, name = item.name, token = '<me>' };
    end
    return nil, 'unknown action';
end

M.level_gap = level_gap;

-- the vocabulary's own word for the reaction, for messages
function M.label(act)
    local k = vocab.kind(act.reaction, act.selector);
    return k and k.label or act.reaction;
end

return M;
