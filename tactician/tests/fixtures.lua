-- Shared factories: a small catalog and a snapshot of a white mage in a party, fighting.
local catalog = require('lib.catalog');

local F = {};

-- target flag bits as the client DATs use them
F.SELF, F.PLAYER, F.PARTY, F.ALLY, F.NPC, F.ENEMY, F.CORPSE = 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x80;
local FRIENDLY = F.SELF + F.PLAYER + F.PARTY + F.ALLY;

function F.data()
    return {
        spells = {
            { id = 1,   name = 'Cure',           mp = 8,  cast = 2,   targets = FRIENDLY,  levels = { [3] = 1, [5] = 3, [7] = 5 } },
            { id = 2,   name = 'Cure II',        mp = 24, cast = 2.5, targets = FRIENDLY,  levels = { [3] = 11, [5] = 14, [7] = 17 } },
            { id = 3,   name = 'Cure III',       mp = 46, cast = 2.5, targets = FRIENDLY,  levels = { [3] = 21, [5] = 26, [7] = 30 } },
            { id = 4,   name = 'Cure IV',        mp = 88, cast = 2.75, targets = FRIENDLY, levels = { [3] = 41, [5] = 48, [7] = 55 } },
            { id = 12,  name = 'Raise',          mp = 150, cast = 8,  targets = F.CORPSE,  levels = { [3] = 25, [5] = 35, [7] = 50 } },
            { id = 23,  name = 'Dia',            mp = 7,  cast = 1.5, targets = F.ENEMY,   levels = { [3] = 3, [5] = 1 } },
            { id = 43,  name = 'Protect',        mp = 9,  cast = 3,   targets = FRIENDLY,  levels = { [3] = 7, [5] = 7, [7] = 10 } },
            { id = 44,  name = 'Protect II',     mp = 28, cast = 3,   targets = FRIENDLY,  levels = { [3] = 27, [5] = 27, [7] = 30 } },
            { id = 125, name = 'Protectra',      mp = 9,  cast = 3,   targets = F.SELF,    levels = { [3] = 7 } },
            { id = 144, name = 'Fire',           mp = 7,  cast = 2,   targets = F.ENEMY,   levels = { [4] = 13, [5] = 19 } },
            { id = 145, name = 'Fire II',        mp = 40, cast = 3,   targets = F.ENEMY,   levels = { [4] = 38, [5] = 50 } },
            { id = 252, name = 'Stun',           mp = 25, cast = 0.5, targets = F.ENEMY,   levels = { [8] = 37 } },
            { id = 338, name = 'Utsusemi: Ichi', mp = 0,  cast = 4,   targets = F.SELF,    levels = { [13] = 12 } },
            { id = 273, name = 'Sleepga',        mp = 19, cast = 3,   targets = F.ENEMY,   levels = { [4] = 31 } },
            { id = 274, name = 'Sleepga',        mp = 19, cast = 3,   targets = F.ENEMY,   levels = { [4] = 31 } },
        },
        abilities = {
            { id = 547, name = 'Provoke',          timer = 5,  targets = F.ENEMY, tp = 0 },
            { id = 608, name = 'Curing Waltz',     timer = 66, targets = FRIENDLY, tp = 200 },
            { id = 609, name = 'Curing Waltz II',  timer = 67, targets = FRIENDLY, tp = 350 },
            { id = 528, name = 'Divine Seal',      timer = 13, targets = F.SELF, tp = 0 },
        },
        weaponskills = {
            { id = 32, name = 'Fast Blade' },
            { id = 1,  name = 'Combo' },
        },
        statuses = {
            { id = 2,  name = 'Weakness' },
            { id = 40, name = 'Protect' },
            { id = 65, name = 'Sneak Attack' },
            { id = 66, name = 'Copy Image' },
            -- the DATs repeat a name across ids and pad gaps with bracketed placeholders
            { id = 594, name = 'Bewildered Daze' },
            { id = 595, name = 'Bewildered Daze' },
            { id = 600, name = '(None)' },
            { id = 601, name = '(Imagery)' },
        },
        items = {
            { id = 4116, name = 'Hi-Potion' },
        },
    };
end

function F.catalog()
    return catalog.build(F.data());
end

-- A level 41 WHM/BLM with a party of three (a PLD tank, a dead BLM, a RNG) fighting a mob.
function F.snapshot(over)
    local snap = {
        now = 1000,
        me = { id = 100, idx = 0x400, name = 'Me', hpp = 80, mpp = 60, tp = 1200, hp = 800, hpmax = 1000, mp = 300,
               buffs = { [40] = true }, job = 3, level = 41, sub = 4, sublevel = 20, status = 'engaged' },
        party = {
            { slot = 1, id = 101, idx = 0x401, name = 'Tank',  hpp = 45, mpp = 70, tp = 300,  buffs = {}, job = 7, level = 41 },
            { slot = 2, id = 102, idx = 0x402, name = 'Dead',  hpp = 0,  mpp = 0,  tp = 0,    buffs = { [2] = true }, job = 4, level = 40 },
            { slot = 3, id = 103, idx = 0x403, name = 'Arrow', hpp = 90, mpp = 0,  tp = 1500, buffs = nil, job = 11, level = 41 },
        },
        target = { id = 500, idx = 0x10, name = 'Goblin', hpp = 70, casting = false, readying = false },
        pet = nil,
        recast = { spell = {}, ability = {} },
        items = { [4116] = 2 },
        known = {
            spell = { [1] = true, [2] = true, [3] = true, [4] = true, [12] = true, [23] = true, [43] = true, [44] = true,
                      [125] = true, [144] = true },
            ability = { [528] = true },
            ws = { [32] = true },
        },
    };
    for k, v in pairs(over or {}) do snap[k] = v; end
    return snap;
end

return F;
