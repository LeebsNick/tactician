--[[
* lib/commands - The /tactician slash commands.
*
* handle(S, e) takes Ashita's command event: it claims every /tactician line, toggles the editor
* when there is no sub-command, and otherwise looks the sub-command up in COMMANDS below. Each
* command is a small function of (S, arg1, arg2, raw) where raw is the whole line after
* /tactician, kept for `add`, whose rule text may contain spaces.
*
* Commands that change the rules go through commit, so a no-op change says so and nothing is
* written unless the document differs from the saved one.
--]]

local afk      = require('lib.afk');
local cost     = require('lib.cost');
local document = require('lib.document');
local rule     = require('lib.rule');
local session  = require('lib.session');

local M = {};

local USAGE = 'Usage: /tactician [on | off | list | add <rule> | template | del <n> | move <n> <m> | toggle <n> | reload | status | show | hide]';

-- Save next_doc as the rules and say `done`, unless it is the same document already saved.
local function commit(S, next_doc, done)
    if document.same(next_doc, S.doc) then session.say('Nothing to change.'); return; end
    if session.save(S, next_doc) then session.say(done); end
end

-- One entry per sub-command, keyed by its lower-case name.
local COMMANDS = {
    -- /tactician on|off: the Run switch
    on   = function(S) session.set_run(S, true); end,
    off  = function(S) session.set_run(S, false); end,
    -- /tactician show|hide: the editor window
    show = function(S) S.ui.show[1] = true; end,
    hide = function(S) S.ui.show[1] = false; end,
    -- /tactician list: the saved rules, numbered
    list = function(S)
        if #S.doc.rules == 0 then
            local hint = S.template and '/tactician template for a starting set, ' or '';
            session.say(('No %s rules yet. %s/tactician add <rule>, or open the editor.'):format(S.job or '', hint));
            return;
        end
        for i, line in ipairs(document.lines(S.doc)) do session.say(('%d. %s'):format(i, line)); end
    end,
    -- /tactician add <rule>: parse the rest of the line as one rule and append it
    add = function(S, _, _, raw)
        local line = raw and raw:match('^%s*add%s+(.-)%s*$');
        if line == nil or line == '' then session.say('Usage: /tactician add <scope> <if> <then> [retry:<s>]'); return; end
        local r, err = rule.parse(line);
        if r == nil then session.say('Not a rule: ' .. err); return; end
        commit(S, document.add(S.doc, r), ('Added rule %d.'):format(#S.doc.rules + 1));
    end,
    -- /tactician template: append the job's shipped starting set, comments included
    template = function(S)
        if S.template == nil then session.say(('No %s template ships. Open the editor to start from scratch.'):format(S.job or '')); return; end
        local next_doc = S.doc;
        for _, r in ipairs(S.template.rules) do next_doc = document.add(next_doc, r); end
        commit(S, next_doc, ('Added the %s template; /tactician list to read it.'):format(S.job));
    end,
    -- /tactician del <n>
    del = function(S, n)
        n = tonumber(n);
        if n == nil or S.doc.rules[n] == nil then session.say('Which rule? /tactician list'); return; end
        commit(S, document.remove(S.doc, n), ('Deleted rule %d.'):format(n));
    end,
    -- /tactician move <n> <m>
    move = function(S, n, m)
        n, m = tonumber(n), tonumber(m);
        if n == nil or m == nil or S.doc.rules[n] == nil or S.doc.rules[m] == nil then session.say('Usage: /tactician move <n> <m>'); return; end
        commit(S, document.move(S.doc, n, m), ('Moved rule %d to %d.'):format(n, m));
    end,
    -- /tactician toggle <n>: a raw (unparsed) line has no on/off to switch
    toggle = function(S, n)
        n = tonumber(n);
        if n == nil or S.doc.rules[n] == nil or S.doc.rules[n].raw then session.say('Which rule? /tactician list'); return; end
        local next_doc = document.toggle(S.doc, n);
        commit(S, next_doc, ('Rule %d %s.'):format(n, next_doc.rules[n].enabled and 'on' or 'off'));
    end,
    -- /tactician reload: re-read the file; nothing to read before the first tick names the character
    reload = function(S)
        if S.char then session.load(S); session.say(('Re-read %s.'):format(session.path(S))); end
    end,
    -- /tactician status: stopped / asleep / running, the pacing phase, the last fire, and what the
    -- addon takes of each frame (the rules tick and the editor window, over the last second)
    status = function(S)
        local state = not S.run and 'stopped' or (afk.asleep(S.rest) and 'asleep (move or press a key to wake)' or 'running');
        session.say(('%s; %s; last: %s'):format(state, S.pace.phase, S.ui.last ~= '' and S.ui.last or 'nothing yet'));
        session.say(('Frame cost: tick %s; editor %s.'):format(cost.text(S.cost.tick), cost.text(S.cost.draw)));
    end,
};

-- Ashita's command event. Lines that are not /tactician pass through untouched.
function M.handle(S, e)
    local args = e.command:args();
    if #args == 0 or args[1]:lower() ~= '/tactician' then return; end
    e.blocked = true;
    if args[2] == nil then S.ui.show[1] = not S.ui.show[1]; return; end
    local cmd = COMMANDS[args[2]:lower()];
    if cmd == nil then session.say(USAGE); return; end
    cmd(S, args[3], args[4], e.command:match('^%S+%s+(.*)$'));
end

return M;
