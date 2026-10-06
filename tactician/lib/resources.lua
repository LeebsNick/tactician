--[[
* lib/resources - What the client knows that a rule can name: spells, abilities, weapon skills
* and statuses from the DATs, the items in the bags, and the party's status icons from memory.
*
* Every function here reads Ashita and returns plain tables; nothing is kept between calls.
* tactician.lua reads the DATs once and the bags every few seconds, then hands the result to
* lib/catalog, which indexes it by name and family for the engine and the editor.
*
* Ashita only: this is the one place besides lib/client that touches AshitaCore directly.
--]]

local actions = require('lib.actions');
local client  = require('lib.client');

local M = {};

-- DAT id ranges. Spell ids 896-1023 are trust calls, which a rule may not cast. Job ability
-- DAT ids are 512 + the server id, with pet commands following; weapon skills are ability
-- ids with no offset.
local SPELL_LAST              = 1299;
local TRUST_FIRST, TRUST_LAST = 896, 1023;
local JA_FIRST, JA_LAST       = 513, 1023;
local WS_LAST                 = 255;
local STATUS_LAST             = 1023;

-- Menu headers the DATs list as abilities; HasAbility answers true for them and they do nothing.
local HEADERS = { Sambas = true, Waltzes = true, Steps = true, Jigs = true, ['Flourishes I'] = true,
                  ['Flourishes II'] = true, ['Flourishes III'] = true };

-- The English name of a DAT entry, or nil for the blank and '.' placeholders the DATs carry.
-- Name is a userdata array, so the read is guarded.
local function named(entry)
    local ok, name = pcall(function() return entry.Name[1]; end);
    if ok and type(name) == 'string' and #name > 1 and name ~= '.' then return name; end
    return nil;
end

-- Every spell a job can learn: { id, name, mp, cast, targets, levels }, levels keyed by the
-- index of the job in lib/actions JOBS. LevelRequired is the DAT's 24 int16 entries from job 0,
-- handed to Lua 1-based.
local function spells(res)
    local out = {};
    for id = 1, SPELL_LAST do
        if id < TRUST_FIRST or id > TRUST_LAST then
            local s = res:GetSpellById(id);
            local name = s and named(s);
            if name then
                local levels = {};
                for j = 1, #actions.JOBS do
                    local lvl = s.LevelRequired[j + 1];
                    if type(lvl) == 'number' and lvl >= 1 and lvl <= 99 then levels[j] = lvl; end
                end
                if next(levels) then
                    table.insert(out, { id = id, name = name, mp = s.ManaCost, cast = s.CastTime / 4,
                                        targets = s.Targets, levels = levels });
                end
            end
        end
    end
    return out;
end

-- Job abilities and pet commands: { id, name, timer, targets, tp }, headers left out.
local function abilities(res)
    local out = {};
    for id = JA_FIRST, JA_LAST do
        local a = res:GetAbilityById(id);
        local name = a and named(a);
        if name and not HEADERS[name] then
            table.insert(out, { id = id, name = name, timer = a.RecastTimerId, targets = a.Targets, tp = a.TPCost });
        end
    end
    return out;
end

-- Weapon skills: { id, name }.
local function weaponskills(res)
    local out = {};
    for id = 1, WS_LAST do
        local a = res:GetAbilityById(id);
        local name = a and named(a);
        if name then table.insert(out, { id = id, name = name }); end
    end
    return out;
end

-- Status effects by buff id: { id, name }.
local function statuses(res)
    local out = {};
    for id = 1, STATUS_LAST do
        local name = res:GetString('buffs.names', id);
        if name ~= nil and #name > 0 then table.insert(out, { id = id, name = name }); end
    end
    return out;
end

-- The DAT lists in one table. They do not change while the client runs, so the caller reads
-- them once. Raises if the resource manager is not ready; the caller pcalls.
function M.static()
    local res = AshitaCore:GetResourceManager();
    return { spells = spells(res), abilities = abilities(res), weaponskills = weaponskills(res), statuses = statuses(res) };
end

-- Every distinct item across the bags lib/client reads: { id, name }. Changes as bags change,
-- so the caller re-reads it every few seconds.
function M.items(mm)
    local res, inv, out, seen = AshitaCore:GetResourceManager(), mm:GetInventory(), {}, {};
    for _, bag in ipairs(client.BAGS) do
        for i = 0, inv:GetContainerCountMax(bag) do
            local item = inv:GetContainerItem(bag, i);
            if item ~= nil and item.Id ~= 0 and not seen[item.Id] then
                seen[item.Id] = true;
                local r = res:GetItemById(item.Id);
                local name = r and named(r);
                if name then table.insert(out, { id = item.Id, name = name }); end
            end
        end
    end
    return out;
end

-- Party members' buff ids from the party.statusicons block in memory, decoded by lib/client.
-- Any read failure answers an empty table rather than stopping the tick.
function M.party_buffs()
    local ok, out = pcall(function()
        local base = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('party.statusicons'));
        if base == nil or base == 0 then return {}; end
        return client.party_buffs(ashita.memory.read_uint8, ashita.memory.read_uint32, base);
    end);
    return ok and out or {};
end

return M;
