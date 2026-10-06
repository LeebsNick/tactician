-- Reads the game into a plain snapshot. Every function takes the Ashita manager objects it
-- needs in one table (mm.party, mm.player, mm.entity, mm.target, mm.recast, mm.inventory)
-- so tests hand in tables with the same method names. No other Ashita use lives here.
local M = {};

M.SPAWN_MOB = 0x10;          -- GetSpawnFlags bit for monsters
M.BAGS      = { 0, 3 };      -- inventory and temporary items
M.STATUS    = { [0] = 'idle', [1] = 'engaged', [2] = 'dead', [3] = 'dead', [4] = 'event', [33] = 'resting' };

-- a status list (32 int16 slots, 0 or 255 for empty) as a set of ids
function M.buffs(list)
    local out = {};
    for _, id in ipairs(list or {}) do
        if id ~= nil and id > 0 and id ~= 255 then out[id] = true; end
    end
    return out;
end

local function clean(name)
    return (tostring(name or ''):gsub('_', ' '));
end

local function pos(entity, idx)
    return { x = entity:GetLocalPositionX(idx), y = entity:GetLocalPositionY(idx), z = entity:GetLocalPositionZ(idx) };
end

function M.me(mm)
    local party, player, entity = mm.party, mm.player, mm.entity;
    local idx = party:GetMemberTargetIndex(0);
    return {
        id = party:GetMemberServerId(0), idx = idx, name = clean(party:GetMemberName(0)),
        hpp = party:GetMemberHPPercent(0), mpp = party:GetMemberMPPercent(0), tp = party:GetMemberTP(0),
        hp = party:GetMemberHP(0), hpmax = player:GetHPMax(), mp = party:GetMemberMP(0),
        buffs = M.buffs(player:GetBuffs()),
        job = player:GetMainJob(), level = player:GetMainJobLevel(), sub = player:GetSubJob(), sublevel = player:GetSubJobLevel(),
        status = M.STATUS[entity:GetStatus(idx)] or 'other', pos = pos(entity, idx),
        zoning = player:GetIsZoning() ~= 0,
    };
end

-- buffs_by_id: { [serverId] = set } from party_buffs below; a member missing from it has nil buffs
function M.party(mm, buffs_by_id)
    local party = mm.party;
    local zone  = party:GetMemberZone(0);
    local out   = {};
    for i = 1, 5 do
        if party:GetMemberIsActive(i) == 1 and party:GetMemberZone(i) == zone then
            local id, idx = party:GetMemberServerId(i), party:GetMemberTargetIndex(i);
            table.insert(out, {
                slot = i, id = id, idx = idx, name = clean(party:GetMemberName(i)),
                status = M.STATUS[mm.entity:GetStatus(idx)] or 'other', pos = pos(mm.entity, idx),
                hpp = party:GetMemberHPPercent(i), mpp = party:GetMemberMPPercent(i), tp = party:GetMemberTP(i),
                buffs = buffs_by_id and buffs_by_id[id] or nil,
                job = party:GetMemberMainJob(i), level = party:GetMemberMainJobLevel(i),
            });
        end
    end
    return out;
end

-- flags: lib/tracker flags for the targeted entity
function M.target(mm, flags)
    local idx = mm.target:GetTargetIndex(0);
    if idx == nil or idx == 0 then return nil; end
    local entity = mm.entity;
    if bit.band(entity:GetSpawnFlags(idx), M.SPAWN_MOB) == 0 then return nil; end
    local hpp = entity:GetHPPercent(idx);
    if hpp == 0 then return nil; end
    return { id = entity:GetServerId(idx), idx = idx, name = clean(entity:GetName(idx)), hpp = hpp,
             casting = flags.casting == true, readying = flags.readying == true };
end

function M.pet(mm, my_idx)
    local idx = mm.entity:GetPetTargetIndex(my_idx);
    if idx == nil or idx == 0 then return nil; end
    return { id = mm.entity:GetServerId(idx), idx = idx, name = clean(mm.entity:GetName(idx)), hpp = mm.entity:GetHPPercent(idx),
             mpp = mm.player:GetPetMPPercent(), tp = mm.player:GetPetTP() };
end

-- seconds left, by spell id and by ability recast timer id (the two-hour sits in slot 0 with timer id 0)
function M.recasts(mm, spell_ids)
    local out = { spell = {}, ability = {} };
    for _, id in ipairs(spell_ids) do
        local t = mm.recast:GetSpellTimer(id);
        if t and t > 0 then out.spell[id] = t / 60; end
    end
    for x = 0, 31 do
        local id, t = mm.recast:GetAbilityTimerId(x), mm.recast:GetAbilityTimer(x);
        if t and t > 0 and (id ~= 0 or x == 0) then out.ability[id] = t / 60; end
    end
    return out;
end

function M.items(mm)
    local out = {};
    for _, bag in ipairs(M.BAGS) do
        for i = 0, mm.inventory:GetContainerCountMax(bag) do
            local item = mm.inventory:GetContainerItem(bag, i);
            if item ~= nil and item.Id ~= 0 and item.Count > 0 then out[item.Id] = (out[item.Id] or 0) + item.Count; end
        end
    end
    return out;
end

function M.known(mm, cat)
    local out = { spell = {}, ability = {}, ws = {} };
    for id in pairs(cat.spells) do if mm.player:HasSpell(id) then out.spell[id] = true; end end
    for id in pairs(cat.abilities) do if mm.player:HasAbility(id) then out.ability[id] = true; end end
    for id in pairs(cat.weaponskills) do if mm.player:HasWeaponSkill(id) then out.ws[id] = true; end end
    return out;
end

-- The client keeps the other party members' statuses in five 0x30-byte blocks: server id at
-- 0, two high bits per status packed from byte 8, low bytes from byte 16, 255 ends the list.
-- read8/read32 read memory at an address; base is the first block.
function M.party_buffs(read8, read32, base)
    local out = {};
    for m = 0, 4 do
        local ptr = base + 0x30 * m;
        local id  = read32(ptr);
        if id ~= 0 then
            local set = {};
            for j = 0, 31 do
                local high = bit.band(bit.rshift(read8(ptr + 8 + math.floor(j / 4)), (j % 4) * 2), 0x03) * 256;
                local v    = high + read8(ptr + 16 + j);
                if v == 255 then break; end
                if v > 0 then set[v] = true; end
            end
            out[id] = set;
        end
    end
    return out;
end

-- extras = { now, party_buffs, tracker (flags for the target), known (cached lib/client.known) }
function M.snapshot(mm, cat, extras)
    local me = M.me(mm);
    return {
        now = extras.now, me = me,
        party = M.party(mm, extras.party_buffs),
        target = M.target(mm, extras.tracker or {}),
        pet = M.pet(mm, me.idx),
        recast = M.recasts(mm, cat.spell_ids),
        items = M.items(mm),
        known = extras.known or M.known(mm, cat),
    };
end

return M;
