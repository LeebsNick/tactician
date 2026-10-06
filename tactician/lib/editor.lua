--[[
* lib/editor - The Tactician window: one row per rule of the current job, edited in place and
* saved back to the rule file.
*
* draw(S) is the only entry point; tactician.lua calls it every frame. The editor works on S.edit,
* a copy of the saved document S.doc, and nothing it changes runs until Save writes it through
* lib/session. Every row control makes a new document through lib/document rather than mutating
* the old one, so Revert is just S.edit = S.doc.
*
* The look follows the Sidekick config window: a near-black window, navy frames, a blue accent,
* yellow row numbers, no column headers, and the row that fired last shaded green. Off rows are
* drawn at half alpha. The dropdown entries and the inert-rule notes come from lib/view; this
* file is ImGui calls.
--]]

local imgui    = require('imgui');
local afk      = require('lib.afk');
local cost     = require('lib.cost');
local document = require('lib.document');
local rule     = require('lib.rule');
local session  = require('lib.session');
local view     = require('lib.view');
local vocab    = require('lib.vocab');

local M = {};

-- The state table, bound by draw each frame. One addon draws one window, so the row helpers
-- read it as an upvalue instead of threading it through every call.
local S;

local C = {
    fg     = { 0.90, 0.90, 0.90, 1.0 },
    dim    = { 0.50, 0.50, 0.50, 1.0 },
    yellow = { 1.00, 1.00, 0.70, 1.0 },  -- row numbers
    green  = { 0.70, 1.00, 0.70, 1.0 },  -- running, saved, the last fire
    red    = { 1.00, 0.70, 0.70, 1.0 },  -- a rule that can never fire, an unsaved edit
    fired  = { 0.24, 0.47, 0.24, 0.55 }, -- the row that fired last
    frame  = { 0.16, 0.19, 0.29, 1.0 },
    hover  = { 0.24, 0.29, 0.48, 1.0 },
    active = { 0.29, 0.35, 0.60, 1.0 },
    accent = { 0.26, 0.59, 0.98, 1.0 },
    border = { 0.23, 0.23, 0.23, 1.0 },
};

-- Pushed around the window each frame, popped as one.
local STYLE = {
    { ImGuiCol_WindowBg,         { 0.06, 0.06, 0.06, 0.95 } },
    { ImGuiCol_PopupBg,          { 0.08, 0.08, 0.13, 0.98 } },
    { ImGuiCol_TitleBg,          { 0.10, 0.10, 0.18, 1.0 } },
    { ImGuiCol_TitleBgActive,    { 0.10, 0.10, 0.18, 1.0 } },
    { ImGuiCol_Border,           C.border },
    { ImGuiCol_Separator,        C.border },
    { ImGuiCol_FrameBg,          C.frame },
    { ImGuiCol_FrameBgHovered,   C.hover },
    { ImGuiCol_FrameBgActive,    C.active },
    { ImGuiCol_Button,           { 0.18, 0.23, 0.40, 1.0 } },
    { ImGuiCol_ButtonHovered,    { 0.24, 0.30, 0.54, 1.0 } },
    { ImGuiCol_ButtonActive,     C.active },
    { ImGuiCol_Header,           C.frame },
    { ImGuiCol_HeaderHovered,    C.hover },
    { ImGuiCol_HeaderActive,     C.active },
    { ImGuiCol_CheckMark,        C.accent },
    { ImGuiCol_SliderGrab,       C.accent },
    { ImGuiCol_SliderGrabActive, C.accent },
    { ImGuiCol_Text,             C.fg },
    { ImGuiCol_TextDisabled,     C.dim },
};
local OFF_ALPHA     = 0.45;  -- how faint an off rule's controls are drawn
local LIST_ROWS     = 12;    -- rows a picker shows before it scrolls
local TEMPLATE_ROWS = 8;     -- rows the template panel shows before it scrolls
local MIN           = view.MIN;

-- An { r, g, b, a } colour as the packed integer a table row background takes.
local function packed(c)
    local function byte(v) return math.floor(v * 255 + 0.5); end
    return byte(c[4]) * 16777216 + byte(c[3]) * 65536 + byte(c[2]) * 256 + byte(c[1]);
end

-- A tooltip on the item drawn just before, when text is given.
local function tip(text)
    if text and imgui.IsItemHovered() then imgui.SetTooltip(text); end
end

-- The gap ImGui leaves between items on a line.
local function spacing()
    return imgui.GetStyle().ItemSpacing.x;
end

-- True when text would be cut off in a frame leaving room pixels for it.
local function cut(text, room)
    return imgui.CalcTextSize(text) > room - imgui.GetStyle().FramePadding.x * 2;
end

-- A short dropdown of { label, value, note } entries; returns the value picked this frame.
-- The closed box shows its whole text on hover when the width cuts it short.
local function choice(id, width, current, entries)
    local picked = nil;
    imgui.SetNextItemWidth(width);
    local open = imgui.BeginCombo(id, current);
    if open then
        for n, e in ipairs(entries) do
            if imgui.Selectable(('%s##%s%d'):format(e.label, id, n), e.label == current) then picked = e.value; end
            tip(e.note);
        end
        imgui.EndCombo();
    elseif cut(current, width - imgui.GetFrameHeight()) then
        tip(current);
    end
    return picked;
end

-- A button that opens a searchable list for the long catalogs (spells, abilities, items,
-- statuses). An entry the rule could not use right now is listed all the same, with the
-- reason beside it, so the rule can be written ahead of the level. Returns the value picked.
local function picker(id, width, current, entries)
    local picked = nil;
    local label  = current ~= '' and current or 'pick';
    if imgui.Button(('%s##%s'):format(label, id), { width, 0 }) then
        S.search.id, S.search.text[1] = id, '';
        imgui.OpenPopup(id);
    end
    if cut(label, width) then tip(label); end
    if not imgui.BeginPopup(id) then return nil; end
    if S.search.id == id then
        imgui.SetKeyboardFocusHere();
        S.search.id = nil;
    end
    imgui.SetNextItemWidth(220);
    imgui.InputTextWithHint('##search' .. id, 'search', S.search.text, 48);
    local needle = S.search.text[1]:lower();
    imgui.BeginChild('##list' .. id, { 300, imgui.GetTextLineHeightWithSpacing() * LIST_ROWS }, false);
    local shown = 0;
    for n, e in ipairs(entries) do
        if needle == '' or e.label:lower():find(needle, 1, true) then
            shown = shown + 1;
            if imgui.Selectable(('%s##%s%d'):format(e.label, id, n), e.value == current) then
                picked = e.value;
                imgui.CloseCurrentPopup();
            end
            if e.why then imgui.SameLine(); imgui.TextDisabled(e.why); end
        end
    end
    if shown == 0 then imgui.TextDisabled('No match.'); end
    imgui.EndChild();
    imgui.EndPopup();
    return picked;
end

-- vocab entries ({ key, label, note }) as choice entries ({ label, value, note }).
local function options(list)
    local out = {};
    for _, e in ipairs(list) do table.insert(out, { label = e.label, value = e.key, note = e.note }); end
    return out;
end

local SCOPE_OPTIONS = options(vocab.targets);
local KIND_OPTIONS  = options(vocab.kinds);
local LOGIC_OPTIONS = { { label = 'and', value = 'and' }, { label = 'or', value = 'or' } };
-- The condition entries a scope can take, built the first time a row with that scope is drawn.
local COND_OPTIONS  = setmetatable({}, { __index = function(t, scope)
    t[scope] = options(view.condition_options(scope));
    return t[scope];
end });

-- The picker entries for a kind (spell, ability, item, status), built once per refresh.
local function pick_list(kind)
    if S.picks[kind] == nil then S.picks[kind] = view.picks(kind, S.cat, S.snap); end
    return S.picks[kind];
end

-- Copies rule i, lets fn change the copy, and puts it in the editor's document.
local function patch(i, fn)
    local r = S.edit.rules[i];
    local c = { enabled = r.enabled, scope = r.scope, logic = r.logic, retry = r.retry, conds = {},
                act = { reaction = r.act.reaction, selector = r.act.selector, arg = r.act.arg } };
    for k, cond in ipairs(r.conds) do c.conds[k] = { key = cond.key, arg = cond.arg }; end
    fn(c);
    S.edit = document.set(S.edit, i, c);
end

-- The argument a condition starts with when it is picked: 50 clamped to its range, or an empty status.
local function default_arg(key)
    local c = vocab.condition(key);
    if c.arg == 'number' then return math.min(math.max(50, c.min), c.max); end
    if c.arg == 'status' then return ''; end
    return nil;
end

-- Condition k of rule i: its dropdown, width wide, then a slider or a status picker as the condition takes.
local function condition_cell(i, r, k, width)
    local cond = r.conds[k];
    local c    = vocab.condition(cond.key);
    local id   = ('##c%d_%d'):format(k, i);
    local key  = choice(id, width, c and c.label or cond.key, COND_OPTIONS[r.scope]);
    if key then patch(i, function(x) x.conds[k] = { key = key, arg = default_arg(key) }; end); end
    if c == nil then return; end
    if c.arg == 'number' then
        imgui.SameLine();
        local v = { cond.arg or c.min };
        imgui.SetNextItemWidth(MIN.arg);
        if imgui.SliderInt(id .. 'n', v, c.min, c.max, '%d' .. (c.unit == '%' and '%%' or c.unit)) then
            patch(i, function(x) x.conds[k].arg = math.min(math.max(v[1], c.min), c.max); end);
        end
        tip('Drag, or ctrl-click to type.');
    elseif c.arg == 'status' then
        imgui.SameLine();
        local name = picker(id .. 's', MIN.arg, cond.arg, pick_list('status'));
        if name then patch(i, function(x) x.conds[k].arg = name; end); end
    end
end

-- The If column: one condition, or two joined by and / or, with a button to add or drop the
-- second. The dropdowns share the column's width (lib/view.if_width) so they grow with the window.
local function if_cell(i, r)
    local width = view.if_width(imgui.GetContentRegionAvail(), r, spacing());
    condition_cell(i, r, 1, width);
    imgui.SameLine();
    if r.conds[2] then
        local logic = choice(('##l%d'):format(i), MIN.logic, r.logic or 'and', LOGIC_OPTIONS);
        if logic then patch(i, function(x) x.logic = logic; end); end
        imgui.SameLine();
        condition_cell(i, r, 2, width);
        imgui.SameLine();
        if imgui.SmallButton(('-##c2%d'):format(i)) then patch(i, function(x) x.conds[2] = nil; x.logic = nil; end); end
        tip('One condition only.');
    else
        if imgui.SmallButton(('+##c2%d'):format(i)) then
            patch(i, function(x) x.conds[2] = { key = 'always' }; x.logic = 'and'; end);
        end
        tip('A second condition.');
    end
end

-- The Then column: an arrow, the kind of action, then a picker for its spell, ability or item
-- when the kind takes one. The two share the column's width, the picker taking the larger part.
local function do_cell(i, r)
    imgui.TextDisabled('->');
    imgui.SameLine();
    local avail  = imgui.GetContentRegionAvail() - spacing();
    local kind_w = math.max(MIN.kind, avail * 0.45);
    local pick_w = math.max(MIN.pick, avail - kind_w);
    local kind = vocab.kind(r.act.reaction, r.act.selector);
    local key  = choice(('##k%d'):format(i), kind_w, kind and kind.label or r.act.reaction, KIND_OPTIONS);
    if key then
        local k = vocab.lookup(vocab.kinds, key);
        patch(i, function(x)
            local before = view.pick_kind(x.act);
            x.act = { reaction = k.reaction, selector = k.selector, arg = k.selector and x.act.arg or nil };
            if k.selector and view.pick_kind(x.act) ~= before then x.act.arg = ''; end
        end);
        return;
    end
    local pk = view.pick_kind(r.act);
    if pk == 'none' then return; end
    imgui.SameLine();
    local name = picker(('##p%d'):format(i), pick_w, r.act.arg, pick_list(pk));
    if name then patch(i, function(x) x.act.arg = name; end); end
end

-- The Retry column: a minus button, the seconds, a plus button. Its own buttons rather than
-- InputInt's step arrows, which were cut off by the narrow column and took no tooltip.
local function retry_cell(i, r)
    local function set(v) patch(i, function(x) x.retry = math.max(0, math.floor(v)); end); end
    if imgui.SmallButton(('-##rm%d'):format(i)) then set(r.retry - 1); end
    tip('A second less.');
    imgui.SameLine();
    local retry = { r.retry };
    imgui.SetNextItemWidth(46);
    if imgui.InputInt(('##r%d'):format(i), retry, 0, 0) then set(retry[1]); end
    tip('Seconds the rule rests after it fires. 0: as soon as the recast allows.');
    imgui.SameLine();
    if imgui.SmallButton(('+##rp%d'):format(i)) then set(r.retry + 1); end
    tip('A second more.');
end

-- The move / copy / delete buttons for rule i.
local function ops_cell(i)
    local n = #S.edit.rules;
    if i > 1 then
        if imgui.SmallButton(('^##u%d'):format(i)) then S.edit = document.move(S.edit, i, i - 1); end
        tip('Up. Higher rules are tried first.');
        imgui.SameLine();
    end
    if i < n then
        if imgui.SmallButton(('v##d%d'):format(i)) then S.edit = document.move(S.edit, i, i + 1); end
        tip('Down.');
        imgui.SameLine();
    end
    if imgui.SmallButton(('+##dup%d'):format(i)) then S.edit = document.duplicate(S.edit, i); end
    tip('Duplicate.');
    imgui.SameLine();
    if imgui.SmallButton(('x##del%d'):format(i)) then S.edit = document.remove(S.edit, i); end
    tip('Delete.');
end

-- One parsed rule as a row: on, number, scope, if, then, the buttons, retry. row is lib/view's row
-- for it, carrying the reason it can never fire if there is one; fired shades the row green.
local function rule_row(i, r, row, fired)
    imgui.TableNextRow();
    if fired then imgui.TableSetBgColor(ImGuiTableBgTarget_RowBg0, packed(C.fired)); end
    imgui.TableNextColumn();
    local on = { r.enabled };
    if imgui.Checkbox(('##on%d'):format(i), on) then S.edit = document.toggle(S.edit, i); end
    tip(r.enabled and 'On. Untick to keep the rule but skip it.' or 'Off. The rule is kept but skipped.');
    imgui.TableNextColumn();
    if row.note then
        imgui.TextColored(C.red, ('%d !'):format(i));
        tip('This rule can never fire: ' .. row.note .. '.');
    else
        imgui.TextColored(r.enabled and C.yellow or C.dim, ('%d'):format(i));
    end
    if not r.enabled then imgui.PushStyleVar(ImGuiStyleVar_Alpha, OFF_ALPHA); end
    imgui.TableNextColumn();
    local scope = choice(('##w%d'):format(i), math.max(MIN.combo, (imgui.GetContentRegionAvail())), vocab.target(r.scope).label, SCOPE_OPTIONS);
    if scope then
        patch(i, function(x)
            x.scope = scope;
            for k, cond in ipairs(x.conds) do
                if not vocab.fits(cond.key, scope) then x.conds[k] = { key = 'always' }; end
            end
        end);
    end
    imgui.TableNextColumn();
    if_cell(i, r);
    imgui.TableNextColumn();
    do_cell(i, r);
    if not r.enabled then imgui.PopStyleVar(); end
    imgui.TableNextColumn();
    ops_cell(i);
    imgui.TableNextColumn();
    retry_cell(i, r);
end

-- A line that did not parse: shown as typed, in red with the parse error if there is one, delete only.
local function raw_row(i, row)
    imgui.TableNextRow();
    imgui.TableNextColumn();
    imgui.TableNextColumn();
    imgui.TextDisabled(('%d'):format(i));
    imgui.TableNextColumn();
    imgui.TableNextColumn();
    if row.error then
        imgui.TextColored(C.red, row.raw);
        tip(row.error .. '. Fix the line in the file, or delete it here.');
    else
        imgui.TextDisabled(row.raw);
    end
    imgui.TableNextColumn();
    imgui.TableNextColumn();
    if imgui.SmallButton(('x##del%d'):format(i)) then S.edit = document.remove(S.edit, i); end
    tip('Delete.');
    imgui.TableNextColumn();
end

-- The first rule the editor would refuse to save, as 'Rule n: why', or nil.
local function first_problem()
    for i, r in ipairs(S.edit.rules) do
        if r.raw == nil then
            local err = rule.check(r);
            if err then return ('Rule %d: %s'):format(i, err); end
        end
    end
    return nil;
end

-- What a frame reads off the documents, worked out once per change rather than once per frame:
-- the rows and their inert notes, the header counts, whether the edit differs from the saved
-- file and its first problem, and the template's rows. A tick replaces S.snap, an edit
-- replaces S.edit, so identity is the change test.
local memo = {};
local function derived()
    if memo.edit ~= S.edit or memo.doc ~= S.doc or memo.snap ~= S.snap or memo.cat ~= S.cat or memo.template ~= S.template then
        memo.edit, memo.doc, memo.snap, memo.cat, memo.template = S.edit, S.doc, S.snap, S.cat, S.template;
        memo.rows     = view.rows(S.edit, S.cat, S.snap);
        memo.summary  = view.summary(S.doc, S.cat, S.snap);
        memo.dirty    = not document.same(S.edit, S.doc);
        memo.problem  = memo.dirty and first_problem() or nil;
        memo.template_rows = S.template and view.rows(S.template, S.cat, S.snap) or nil;
    end
    return memo;
end

-- Above the rows: the Run switch and its state, the rule counts, what the window costs each
-- frame, and a line on how rules are read.
local function header()
    local running = { S.run };
    if imgui.Checkbox('Run', running) then session.set_run(S, running[1]); end
    tip('Run the saved rules. Off at every load; sleeps after ten minutes without a step or a key press from you.');
    imgui.SameLine();
    if S.run and afk.asleep(S.rest) then
        imgui.TextColored(C.red, 'asleep');
        tip(('No step or key press from you for %d minutes. Move or press a key to wake the rules.'):format(afk.TIMEOUT / 60));
    elseif S.run then
        imgui.TextColored(C.green, 'running');
    else
        imgui.TextDisabled('stopped');
    end
    local summary = derived().summary;
    imgui.SameLine();
    imgui.TextDisabled(('%d rules, %d on, %d never fire'):format(summary.rules, summary.on, summary.inert));
    imgui.SameLine();
    imgui.TextColored(cost.heavy(S.cost.draw) and C.red or C.dim, cost.text(S.cost.draw));
    tip(('What this window costs of each frame, over the last second. The rules tick: %s. A 60 fps frame is 16.7 ms.'):format(cost.text(S.cost.tick)));
    imgui.TextDisabled('The first rule that fits fires each tick, top to bottom. Hover anything for help.');
end

-- Below the rows: Add rule, Save, Revert, the note on what state the edit is in, and the last fire.
local function footer(last)
    if imgui.Button('+ Add rule') then S.edit = document.add(S.edit, rule.blank()); end
    imgui.SameLine();
    local dirty, problem = derived().dirty, derived().problem;
    if imgui.Button('Save') then
        if not dirty then session.status(S, 'Already saved.');
        elseif problem then session.status(S, problem);
        elseif session.save(S, S.edit) then session.status(S, ('Saved %s.'):format(session.path(S))); end
    end
    tip('Write the rules to ' .. (S.char and session.path(S) or 'the job file') .. '. Only saved rules run.');
    imgui.SameLine();
    if imgui.Button('Revert') then S.edit = S.doc; session.status(S, ''); end
    tip('Back to the saved file.');
    imgui.SameLine();
    if problem then imgui.TextColored(C.red, problem);
    elseif dirty then imgui.TextColored(C.red, 'Not saved yet.');
    elseif S.ui.status ~= '' then imgui.TextColored(C.green, S.ui.status);
    elseif S.ui.last ~= '' then
        local age = last and (' (%ds ago)'):format(os.clock() - last.at) or '';
        imgui.TextColored(C.green, 'Last: ' .. S.ui.last .. age);
    else imgui.TextDisabled('scope | if | then | retry'); end
end

-- Under the footer: the job's shipped template behind a header that opens to its notes and a
-- table of its rules, each with a button that adds it below the rules above, and buttons to
-- add the whole set or start over with it. Nothing runs until Save.
local function template_panel()
    if S.template == nil then return; end
    local rows, n = derived().template_rows, 0;
    for _, r in ipairs(S.template.rules) do if r.raw == nil then n = n + 1; end end
    S.ui.templates = imgui.CollapsingHeader(('%s template: %d rules###template'):format(S.job, n));
    tip('A starting set of rules for the job, shipped with the addon.');
    if not S.ui.templates then return; end
    if imgui.SmallButton('Add all') then
        for _, r in ipairs(S.template.rules) do S.edit = document.add(S.edit, r); end
    end
    tip('Put every template rule below yours, notes included.');
    imgui.SameLine();
    if imgui.SmallButton('Start over with these') then S.edit = S.template; end
    tip('Replace your rules with the template. Revert undoes it until you Save.');
    imgui.BeginChild('##template', { 0, imgui.GetTextLineHeightWithSpacing() * TEMPLATE_ROWS }, false);
    for _, r in ipairs(S.template.rules) do
        if r.raw then imgui.TextDisabled((r.raw:gsub('^%s*#%s?', ''))); end
    end
    if imgui.BeginTable('##template_rules', 5, ImGuiTableFlags_SizingFixedFit) then
        imgui.TableSetupColumn('',      ImGuiTableColumnFlags_WidthFixed, 22);
        imgui.TableSetupColumn('Scope', ImGuiTableColumnFlags_WidthFixed, 130);
        imgui.TableSetupColumn('If',    ImGuiTableColumnFlags_WidthStretch, 1.2);
        imgui.TableSetupColumn('Then',  ImGuiTableColumnFlags_WidthStretch, 1.0);
        imgui.TableSetupColumn('Retry', ImGuiTableColumnFlags_WidthFixed, 50);
        for i, r in ipairs(S.template.rules) do
            if r.raw == nil then
                imgui.TableNextRow();
                imgui.TableNextColumn();
                if imgui.SmallButton(('+##t%d'):format(i)) then S.edit = document.add(S.edit, r); end
                tip('Add this rule below yours.');
                imgui.TableNextColumn();
                imgui.TextColored(C.yellow, rows[i].scope);
                imgui.TableNextColumn();
                imgui.Text(rows[i].condition);
                imgui.TableNextColumn();
                imgui.Text('-> ' .. rows[i].action);
                if rows[i].note then imgui.SameLine(); imgui.TextColored(C.red, '!'); tip('Right now this rule could not fire: ' .. rows[i].note .. '.'); end
                imgui.TableNextColumn();
                imgui.TextDisabled(rows[i].retry > 0 and ('%ds'):format(rows[i].retry) or '');
            end
        end
        imgui.EndTable();
    end
    imgui.EndChild();
end

-- The height the window keeps under the rule table for the footer and the template panel.
local function reserve()
    local frame = imgui.GetFrameHeightWithSpacing();
    local h = frame * 2;
    if S.template then h = h + frame; end
    if S.template and S.ui.templates then h = h + frame + imgui.GetTextLineHeightWithSpacing() * TEMPLATE_ROWS + spacing(); end
    return h;
end

-- The window body: header, the seven-column rule table with no header row, footer, templates.
local function draw_window()
    header();
    imgui.Separator();
    local last = view.last_fired(S.eng);
    if imgui.BeginTable('##rules', 7, bit.bor(ImGuiTableFlags_ScrollY, ImGuiTableFlags_SizingFixedFit), { -1, -reserve() }) then
        imgui.TableSetupColumn('On',    ImGuiTableColumnFlags_WidthFixed, 26);
        imgui.TableSetupColumn('#',     ImGuiTableColumnFlags_WidthFixed, 34);
        imgui.TableSetupColumn('Scope', ImGuiTableColumnFlags_WidthStretch, 0.5);
        imgui.TableSetupColumn('If',    ImGuiTableColumnFlags_WidthStretch, 1.6);
        imgui.TableSetupColumn('Then',  ImGuiTableColumnFlags_WidthStretch, 1.2);
        imgui.TableSetupColumn('',      ImGuiTableColumnFlags_WidthFixed, 110);
        imgui.TableSetupColumn('Retry', ImGuiTableColumnFlags_WidthFixed, 100);
        local rows = derived().rows;
        for i, r in ipairs(S.edit.rules) do
            if r.raw then raw_row(i, rows[i]); else rule_row(i, r, rows[i], last ~= nil and last.index == i); end
        end
        imgui.EndTable();
    end
    imgui.Separator();
    footer(last);
    template_panel();
end

-- One frame of the window, if it is open and the first tick has given it a catalog and a
-- snapshot to describe rules against. An error inside closes the window, since a frame cut
-- short can leave ImGui with a table or popup still open, and is printed once.
function M.draw(state)
    S = state;
    if not S.ui.show[1] or S.cat == nil or S.snap == nil then return; end
    for _, s in ipairs(STYLE) do imgui.PushStyleColor(s[1], s[2]); end
    imgui.SetNextWindowSize({ 1100, 520 }, ImGuiCond_FirstUseEver);
    if imgui.Begin(('Tactician  %s %s###tactician'):format(S.job or '', S.char or ''), S.ui.show, ImGuiWindowFlags_NoCollapse) then
        local ok, err = pcall(draw_window);
        if not ok then
            S.ui.show[1] = false;
            if not S.reported then
                S.reported = true;
                session.say('Editor error, window closed: ' .. tostring(err));
            end
        end
    end
    imgui.End();
    imgui.PopStyleColor(#STYLE);
end

return M;
