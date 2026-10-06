-- Resolves a rule's scope to the subjects it may fire for, in the order they are tried. A
-- subject carries the readings a condition can test and the token the command targets.
local vocab = require('lib.vocab');

local M = {};

local function me_subject(me)
    local missing = nil;
    if me.hp and me.hpmax then missing = me.hpmax - me.hp; end
    return { kind = 'self', token = '<me>', name = me.name, hpp = me.hpp, mpp = me.mpp, tp = me.tp,
             hp_missing = missing, buffs = me.buffs, job = me.job, dead = me.hpp == 0, order = 0 };
end

local function member_subject(m)
    return { kind = 'member', token = ('<p%d>'):format(m.slot), name = m.name, hpp = m.hpp, mpp = m.mpp, tp = m.tp,
             buffs = m.buffs, job = m.job, dead = m.hpp == 0, order = m.slot };
end

local function by_hp(a, b)
    if a.hpp ~= b.hpp then return a.hpp < b.hpp; end
    return a.order < b.order;
end

-- everyone alive, me included, lowest HP first
local function alive(snap, keep)
    local out = {};
    local all = { me_subject(snap.me) };
    for _, m in ipairs(snap.party or {}) do table.insert(all, member_subject(m)); end
    for _, s in ipairs(all) do
        if not s.dead and (keep == nil or keep(s)) then table.insert(out, s); end
    end
    table.sort(out, by_hp);
    return out;
end

function M.candidates(key, snap)
    local t = vocab.target(key);
    if t == nil then return {}; end
    if key == 'self' then return { me_subject(snap.me) }; end
    if key == 'target' then
        local tg = snap.target;
        if not tg then return {}; end
        return { { kind = 'enemy', token = '<t>', name = tg.name, hpp = tg.hpp, casting = tg.casting == true,
                   readying = tg.readying == true, dead = tg.hpp == 0 } };
    end
    if key == 'pet' then
        local p = snap.pet;
        if not p then return {}; end
        return { { kind = 'pet', token = '<pet>', name = p.name, hpp = p.hpp, mpp = p.mpp, tp = p.tp, dead = p.hpp == 0 } };
    end
    if t.dead then
        local out = {};
        for _, m in ipairs(snap.party or {}) do
            if m.hpp == 0 then table.insert(out, member_subject(m)); end
        end
        return out;
    end
    if t.jobs then
        return alive(snap, function(s) return t.jobs[s.job] == true; end);
    end
    return alive(snap);
end

-- A stand-in subject of the scope's kind, for judging a rule when nobody of that kind is around.
function M.sample(key)
    local t = vocab.target(key);
    if t == nil then return nil; end
    if t.group == 'self' then return { kind = 'self', token = '<me>', name = 'me', order = 0 }; end
    if t.group == 'enemy' then return { kind = 'enemy', token = '<t>', name = 'target' }; end
    if t.group == 'pet' then return { kind = 'pet', token = '<pet>', name = 'pet' }; end
    return { kind = 'member', token = '<p1>', name = 'party member', dead = t.dead == true, order = 1 };
end

return M;
