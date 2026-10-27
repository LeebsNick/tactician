-- What the editor window draws: each rule as a sentence with its inert note, the dropdown
-- lists cut to the scope or the kind, and the header counts. Pure; the entry point renders it.
local actions = require('lib.actions');
local catalog = require('lib.catalog');
local engine  = require('lib.engine');
local vocab   = require('lib.vocab');

local M = {};

-- The narrowest the editor draws each control of a rule row, in pixels. The If cell's
-- dropdowns grow with the window from here; the rest stay at these widths.
M.MIN = { scope = 100, combo = 150, arg = 100, logic = 50, button = 22, kind = 170, pick = 160 };

-- The width of each condition dropdown in the If cell: what the column leaves after the
-- scope boxes, the argument boxes, the and / or box and the add / drop button, split between
-- the dropdowns and never under MIN.combo. spacing is the gap ImGui puts between items.
function M.if_width(avail, r, spacing)
    local items, fixed = 1, M.MIN.button;
    for _, cond in ipairs(r.conds) do
        items, fixed = items + 2, fixed + M.MIN.scope;
        local c = vocab.condition(cond.key);
        if c and c.arg ~= 'none' then items, fixed = items + 1, fixed + M.MIN.arg; end
    end
    if r.conds[2] then items, fixed = items + 1, fixed + M.MIN.logic; end
    return math.max(M.MIN.combo, (avail - fixed - spacing * (items - 1)) / #r.conds);
end

function M.condition_text(cond)
    local c = vocab.condition(cond.key);
    local text;
    if c == nil then text = cond.key;
    elseif c.arg == 'none' then text = c.label;
    else text = ('%s %s%s'):format(c.label, tostring(cond.arg), c.unit or ''); end
    if cond.scope and vocab.target(cond.scope) then text = vocab.target(cond.scope).label .. ': ' .. text; end
    return text;
end

function M.if_text(r)
    local text = M.condition_text(r.conds[1]);
    if r.conds[2] then text = text .. ' ' .. r.logic .. ' ' .. M.condition_text(r.conds[2]); end
    return text;
end

local VERB = { ma = 'Cast', ja = 'Use', ws = 'Weapon skill', item = 'Use' };

function M.action_text(act)
    if act.reaction == 'rattack' then return 'Ranged attack'; end
    local verb = VERB[act.reaction] or act.reaction;
    if act.selector == 'highest' then verb = verb .. ' best'; end
    return verb .. ' ' .. tostring(act.arg);
end

function M.rows(doc, cat, snap)
    local out = {};
    for i, r in ipairs(doc.rules) do
        if r.raw then
            out[i] = { n = i, raw = r.raw, error = r.error };
        else
            out[i] = { n = i, enabled = r.enabled, scope = vocab.target(r.scope).label, condition = M.if_text(r),
                       action = M.action_text(r.act), retry = r.retry, note = engine.inert(r, cat, snap) };
        end
    end
    return out;
end

function M.condition_options(scope)
    local out = {};
    for _, c in ipairs(vocab.conditions) do
        if vocab.fits(c.key, scope) then table.insert(out, c); end
    end
    return out;
end

-- which pick list a rule's action chooses from
function M.pick_kind(act)
    if act.selector == 'highest' then return act.reaction == 'ja' and 'ability_family' or 'family'; end
    local k = vocab.kind(act.reaction, act.selector);
    return k and k.pick or 'none';
end

local function entry(name, why)
    local e = { label = name, value = name };
    if why then e.dim = true; e.why = why; end
    return e;
end

local function by_label(a, b)
    return a.label < b.label;
end

-- Whether my main or sub job can cast the spell at some level. What the job pair can never
-- cast is left out of the pickers; what it can cast later is listed greyed with the reason.
local function for_job(spell, me)
    return spell.levels[me.job] ~= nil or spell.levels[me.sub] ~= nil;
end

local function spell_why(spell, snap)
    if not snap.known.spell[spell.id] then return 'not learned'; end
    return actions.level_gap(spell, snap.me);
end

-- The tiers of a spell family my job pair can cast at some level.
local function tiers_for_job(fam, me)
    local out = {};
    for _, s in ipairs(fam.tiers) do
        if for_job(s, me) then table.insert(out, s); end
    end
    return out;
end

-- nil while a learned tier is castable now, else the level the lowest learned tier wants, else not learned
local function family_why(tiers, snap)
    local gap;
    for _, s in ipairs(tiers) do
        if snap.known.spell[s.id] then
            local g = actions.level_gap(s, snap.me);
            if g == nil then return nil; end
            gap = gap or g;
        end
    end
    return gap or 'not learned';
end

local function any_known(tiers, known)
    for _, s in ipairs(tiers) do
        if known[s.id] then return true; end
    end
    return false;
end

-- { { label, value, dim, why } } sorted by name; kind: spell, family, ability, ability_family,
-- weaponskill, item, status or none. Spells and spell families are cut to what my main or sub
-- job can cast at some level, greyed with the reason while not learned or above my level.
-- Abilities and weapon skills are what I have: the client says which I have, not which the job
-- gets later, so there is nothing to grey. Items and statuses have no job or learned state.
function M.picks(kind, cat, snap)
    local out = {};
    if kind == 'spell' then
        for _, s in pairs(cat.spell_by_name) do
            if for_job(s, snap.me) then table.insert(out, entry(s.name, spell_why(s, snap))); end
        end
    elseif kind == 'family' then
        for _, fam in pairs(cat.families.spell) do
            local tiers = tiers_for_job(fam, snap.me);
            if #tiers > 0 then table.insert(out, entry(fam.display, family_why(tiers, snap))); end
        end
    elseif kind == 'ability_family' then
        for _, fam in pairs(cat.families.ability) do
            if any_known(fam.tiers, snap.known.ability) then table.insert(out, entry(fam.display)); end
        end
    elseif kind == 'ability' then
        for _, a in pairs(cat.ability_by_name) do
            if snap.known.ability[a.id] then table.insert(out, entry(a.name)); end
        end
    elseif kind == 'weaponskill' then
        for _, w in pairs(cat.ws_by_name) do
            if snap.known.ws[w.id] then table.insert(out, entry(w.name)); end
        end
    elseif kind == 'item' then
        for _, it in pairs(cat.item_by_name) do table.insert(out, entry(it.name)); end
    elseif kind == 'status' then
        for _, name in ipairs(M.status_names(cat)) do table.insert(out, entry(name)); end
    end
    table.sort(out, by_label);
    return out;
end

-- One entry per name: the DATs give several ids the same name (Bewildered Daze is five) and
-- fill gaps with bracketed placeholders like (None) and (Imagery), which no rule can test.
function M.status_names(cat)
    local out = {};
    for _, id in pairs(cat.status_by_name) do
        local name = cat.statuses[id];
        if name:sub(1, 1) ~= '(' then table.insert(out, name); end
    end
    table.sort(out);
    return out;
end

function M.summary(doc, cat, snap)
    local s = { rules = 0, on = 0, inert = 0 };
    for _, r in ipairs(doc.rules) do
        if r.raw == nil then
            s.rules = s.rules + 1;
            if r.enabled then
                s.on = s.on + 1;
                if engine.inert(r, cat, snap) then s.inert = s.inert + 1; end
            end
        end
    end
    return s;
end

-- The rule that fired most recently as { index, at }, or nil before the first fire. The editor
-- shades that row and shows its age; a load or save resets the engine and so clears it.
function M.last_fired(eng)
    local out = nil;
    for i, at in pairs(eng.fired) do
        if out == nil or at > out.at then out = { index = i, at = at }; end
    end
    return out;
end

-- so the entry point can show a status id by name without its own table
M.status = catalog.status;

return M;
