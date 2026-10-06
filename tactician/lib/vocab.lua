-- The gambit vocabulary: the scope a rule runs over, the condition it tests and the action
-- it takes. Keys and ids follow CatsEyeXI's scripts/globals/gambits.lua (its trust AI), trimmed
-- to what a client can read about its own character, party and target; `id` is that enum
-- value, nil for the two client-only additions (the pet target and the item reaction). Pure
-- data and lookups.
local M = {};

-- Job ids as the client numbers them (1 WAR .. 22 RUN); the role sets are LandSandBoat's
-- gambits_container.h melee_jobs and caster_jobs, plus its PLD/RUN tank and RNG/COR ranged tests.
local function set(list)
    local out = {};
    for _, v in ipairs(list) do out[v] = true; end
    return out;
end

-- group: whose readings a scope exposes. self and party members have HP/MP/TP and statuses,
-- the pet has HP/MP/TP but no visible statuses, a monster has HP only (plus what it is doing).
M.targets = {
    { key = 'self',       id = 0,   label = 'Me',                group = 'self',  note = 'Reads and acts on your own character.' },
    { key = 'party',      id = 1,   label = 'Party member',      group = 'party', note = 'Anyone in the party, you included; the lowest HP first.' },
    { key = 'target',     id = 2,   label = 'My target',         group = 'enemy', note = 'The monster you have targeted.' },
    { key = 'tank',       id = 4,   label = 'Party tank',        group = 'party', jobs = set({ 7, 22 }),
      note = 'A paladin or rune fencer in the party.' },
    { key = 'melee',      id = 5,   label = 'Party melee',       group = 'party', jobs = set({ 1, 2, 6, 7, 8, 9, 12, 13, 14, 16, 18, 19, 22 }),
      note = 'A melee job in the party.' },
    { key = 'ranged',     id = 6,   label = 'Party ranged',      group = 'party', jobs = set({ 11, 17 }),
      note = 'A ranger or corsair in the party.' },
    { key = 'caster',     id = 7,   label = 'Party caster',      group = 'party', jobs = set({ 3, 4, 5, 10, 15, 16, 20, 21, 22 }),
      note = 'A mage job in the party.' },
    { key = 'party_dead', id = 10,  label = 'Dead party member', group = 'party', dead = true,
      note = 'A party member at 0 HP.' },
    { key = 'pet',        id = nil, label = 'My pet',            group = 'pet',   note = 'Your pet, avatar or automaton.' },
};

-- subject: which groups the condition can be read for.
local ANY    = { self = true, party = true, enemy = true, pet = true };
local ALLIES = { self = true, party = true, pet = true };
local BUFFED = { self = true, party = true };
local SELF   = { self = true };
local ENEMY  = { enemy = true };

M.conditions = {
    { key = 'always',      id = 0,  label = 'Always',            arg = 'none',   subject = ANY },
    { key = 'hpp_lt',      id = 1,  label = 'HP below',          arg = 'number', unit = '%', min = 1, max = 100, subject = ANY },
    { key = 'hpp_gte',     id = 2,  label = 'HP at least',       arg = 'number', unit = '%', min = 0, max = 100, subject = ANY },
    { key = 'mpp_lt',      id = 3,  label = 'MP below',          arg = 'number', unit = '%', min = 1, max = 100, subject = ALLIES },
    { key = 'tp_lt',       id = 4,  label = 'TP below',          arg = 'number', unit = '',  min = 1, max = 3000, subject = ALLIES },
    { key = 'tp_gte',      id = 5,  label = 'TP at least',       arg = 'number', unit = '',  min = 0, max = 3000, subject = ALLIES },
    { key = 'status',      id = 6,  label = 'Has effect',        arg = 'status', subject = BUFFED },
    { key = 'not_status',  id = 7,  label = 'Missing effect',    arg = 'status', subject = BUFFED },
    { key = 'readying_ms', id = 15, label = 'Readying a TP move', arg = 'none',  subject = ENEMY },
    { key = 'casting_ma',  id = 17, label = 'Casting a spell',   arg = 'none',   subject = ENEMY },
    { key = 'random',      id = 18, label = 'Chance of',         arg = 'number', unit = '%', min = 1, max = 100, subject = ANY },
    { key = 'hp_missing',  id = 24, label = 'HP missing',        arg = 'number', unit = '',  min = 1, max = 9999, subject = SELF },
};

-- aim: 'enemy' when the action can only land on a monster. pick: which catalog list names its argument.
M.reactions = {
    { key = 'ma',      id = 2,   label = 'Cast a spell',       selectors = { 'specific', 'highest' }, aim = 'any',   pick = 'spell' },
    { key = 'ja',      id = 3,   label = 'Use a job ability',  selectors = { 'specific', 'highest' }, aim = 'any',   pick = 'ability' },
    { key = 'ws',      id = 4,   label = 'Use a weapon skill', selectors = { 'specific' },            aim = 'enemy', pick = 'weaponskill' },
    { key = 'rattack', id = 1,   label = 'Ranged attack',      selectors = {},                        aim = 'enemy', pick = 'none' },
    { key = 'item',    id = nil, label = 'Use an item',        selectors = { 'specific' },            aim = 'any',   pick = 'item' },
};

M.selectors = {
    { key = 'specific', id = 2, label = 'Exactly this',          arg = 'action' },
    { key = 'highest',  id = 0, label = 'Best tier of a family', arg = 'family' },
};

M.logic = { 'and', 'or' };

function M.lookup(list, key)
    for _, entry in ipairs(list) do
        if entry.key == key then return entry; end
    end
    return nil;
end

function M.target(key)    return M.lookup(M.targets, key); end
function M.condition(key) return M.lookup(M.conditions, key); end
function M.reaction(key)  return M.lookup(M.reactions, key); end
function M.selector(key)  return M.lookup(M.selectors, key); end

-- True when the condition can be read for what the scope resolves to.
function M.fits(condition_key, target_key)
    local c, t = M.condition(condition_key), M.target(target_key);
    return c ~= nil and t ~= nil and c.subject[t.group] == true;
end

-- True when the reaction takes that selector (nil for an argument-free reaction).
function M.allows(reaction_key, selector_key)
    local r = M.reaction(reaction_key);
    if r == nil then return false; end
    if selector_key == nil then return #r.selectors == 0; end
    for _, s in ipairs(r.selectors) do
        if s == selector_key then return true; end
    end
    return false;
end

-- One entry per legal reaction and selector pair: what the Then dropdown offers.
M.kinds = {};
for _, r in ipairs(M.reactions) do
    if #r.selectors == 0 then
        table.insert(M.kinds, { key = r.key, reaction = r.key, selector = nil, label = r.label, pick = 'none', aim = r.aim });
    end
    for _, s in ipairs(r.selectors) do
        local sel = M.selector(s);
        table.insert(M.kinds, {
            key = r.key .. ':' .. s, reaction = r.key, selector = s,
            label = s == 'specific' and r.label or (r.label .. ': ' .. sel.label:lower()),
            pick = s == 'highest' and 'family' or r.pick, aim = r.aim,
        });
    end
end

function M.kind(reaction_key, selector_key)
    return M.lookup(M.kinds, selector_key and (reaction_key .. ':' .. selector_key) or reaction_key);
end

return M;
