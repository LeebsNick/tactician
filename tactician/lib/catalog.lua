-- Everything the client knows by name: spells, job abilities, weapon skills, statuses and
-- items, indexed for lookup by name and grouped into tier families. Built once from plain
-- tables the entry point reads out of the resource manager; a duplicate name keeps the
-- lowest id, which is the one the game itself uses.
local tiers = require('lib.tiers');

local M = {};

local function lower(name)
    return (name:lower());
end

local function index(list, by_id, by_name)
    for _, entry in ipairs(list) do
        if by_id[entry.id] == nil then by_id[entry.id] = entry; end
        local key = lower(entry.name);
        if by_name[key] == nil or entry.id < by_name[key].id then by_name[key] = entry; end
    end
end

local function group(list, families)
    for _, entry in ipairs(list) do
        local key, tier = tiers.split(entry.name);
        local fam = families[key] or { display = tiers.display(entry.name), tiers = {} };
        families[key] = fam;
        local taken = false;
        for _, s in ipairs(fam.tiers) do
            if s.tier == tier then taken = true; end
        end
        if not taken then table.insert(fam.tiers, { id = entry.id, tier = tier }); end
    end
    for _, fam in pairs(families) do
        table.sort(fam.tiers, function(a, b) return a.tier < b.tier; end);
    end
end

-- data = { spells = { { id, name, mp, cast, targets, levels = { [job] = level } } },
--          abilities = { { id, name, timer, targets, tp } }, weaponskills = { { id, name } },
--          statuses = { { id, name } }, items = { { id, name } } }
function M.build(data)
    local cat = {
        spells = {}, spell_by_name = {},
        abilities = {}, ability_by_name = {},
        weaponskills = {}, ws_by_name = {},
        statuses = {}, status_by_name = {},
        items = {}, item_by_name = {},
        families = { spell = {}, ability = {} },
        spell_ids = {},
    };
    index(data.spells or {}, cat.spells, cat.spell_by_name);
    index(data.abilities or {}, cat.abilities, cat.ability_by_name);
    index(data.weaponskills or {}, cat.weaponskills, cat.ws_by_name);
    index(data.items or {}, cat.items, cat.item_by_name);
    for _, s in ipairs(data.statuses or {}) do
        if cat.statuses[s.id] == nil then cat.statuses[s.id] = s.name; end
        local key = lower(s.name);
        if cat.status_by_name[key] == nil or s.id < cat.status_by_name[key] then cat.status_by_name[key] = s.id; end
    end
    for id in pairs(cat.spells) do table.insert(cat.spell_ids, id); end
    table.sort(cat.spell_ids);
    group(data.spells or {}, cat.families.spell);
    group(data.abilities or {}, cat.families.ability);
    -- family tiers point at the catalog entries themselves
    for _, which in ipairs({ 'spell', 'ability' }) do
        local by_id = which == 'spell' and cat.spells or cat.abilities;
        for _, fam in pairs(cat.families[which]) do
            for i, t in ipairs(fam.tiers) do fam.tiers[i] = by_id[t.id]; end
        end
    end
    return cat;
end

function M.spell(cat, name)       return cat.spell_by_name[lower(name)]; end
function M.ability(cat, name)     return cat.ability_by_name[lower(name)]; end
function M.weaponskill(cat, name) return cat.ws_by_name[lower(name)]; end
function M.item(cat, name)        return cat.item_by_name[lower(name)]; end
function M.status(cat, name)      return cat.status_by_name[lower(name)]; end

-- which: 'spell' or 'ability'; nil tries both
function M.family(cat, name, which)
    local key = tiers.split(name);
    if which then return cat.families[which][key]; end
    return cat.families.spell[key] or cat.families.ability[key];
end

function M.family_names(cat, which)
    local out = {};
    for _, fam in pairs(cat.families[which]) do table.insert(out, fam.display); end
    table.sort(out);
    return out;
end

return M;
