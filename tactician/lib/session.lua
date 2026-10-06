--[[
* lib/session - The addon's one mutable state table and the moves every surface shares.
*
* tactician.lua creates the table with new() and hands it, as S, to the tick, the slash commands
* and the editor; each reads and writes S.<field> rather than its own copy, so there is one
* place to look for what the addon currently believes. The moves below are the ones more than
* one surface needs: say and status for output, path / load / save for the rule file, set_run
* for the Run switch and switch for a change of character or job.
*
* Ashita only: say prints through chat and save creates the config folder through ashita.fs.
--]]

local chat     = require('chat');
local afk      = require('lib.afk');
local cost     = require('lib.cost');
local document = require('lib.document');
local engine   = require('lib.engine');
local pacing   = require('lib.pacing');
local tracker  = require('lib.tracker');

local M = {};

-- Rule files live under config/addons/tactician/<character>/<JOB>.txt; the starting sets the addon
-- ships, one per job that has one, under its own templates/<JOB>.txt.
local DIR       = ('%s\\config\\addons\\tactician\\'):fmt(AshitaCore:GetInstallPath());
local TEMPLATES = addon.path .. '\\templates\\';

-- A fresh state: nothing loaded, rules off, nothing in flight. Every field is listed here so a
-- reader can see the whole of what the addon tracks in one place.
function M.new()
    return {
        -- whose rules, and for which job; set by switch on the first tick and on a job change
        char = nil,
        job  = nil,
        -- the rules
        doc  = document.new(),  -- the saved rules: what the engine runs
        edit = document.new(),  -- the editor's copy; equals doc until the editor changes it
        template = nil,         -- the shipped starting set for this job, nil when there is none
        eng  = engine.new(),    -- lib/engine: which rule fired when, retry and backoff
        -- the client's lists
        static    = nil,        -- spells, abilities, weapon skills, statuses from the DATs, read once
        cat       = nil,        -- lib/catalog, rebuilt with the bag contents every refresh
        known     = nil,        -- what is learned, re-read every refresh
        refreshed = 0,          -- when cat was last rebuilt; cat == nil forces the first build
        snap      = nil,        -- the last lib/client snapshot the tick took
        -- the run
        run       = false,              -- the Run switch; off at every load
        rest      = afk.new(0),         -- the attended-use gate: lib/afk
        input     = false,              -- a key was pressed since the last tick; read and cleared by the tick
        pace      = pacing.new(),       -- lib/pacing: the one action in flight
        track     = tracker.new(),      -- lib/tracker: what the target is doing
        inflight  = nil,                -- the fire whose command is out
        last_tick = 0,                  -- os.clock of the last tick
        reported  = false,              -- one error print per session, from the tick or the editor
        cost      = { tick = cost.new(0), draw = cost.new(0) },  -- lib/cost: seconds of each frame spent here
        warned    = false,              -- one heavy-frame warning per session
        -- the editor
        picks  = {},                    -- pick lists by kind, cleared on refresh
        search = { text = { '' } },     -- the open picker's search box; id set on the frame it opens
        ui     = { show = { false }, status = '', last = '', templates = false },  -- window open, footer note, last fire, template panel open
    };
end

-- A line in the chat log under the addon's header.
function M.say(msg)
    print(chat.header(addon.name):append(chat.message(msg)));
end

-- The editor footer's note: saved, could not write, rule 3 has a problem.
function M.status(S, msg)
    S.ui.status = msg;
end

-- The rule file for the current character and job.
function M.path(S)
    return ('%s%s\\%s.txt'):format(DIR, S.char, S.job);
end

local function read_lines(p)
    local lines = {};
    local f = io.open(p, 'r');
    if f == nil then return lines; end
    for line in f:lines() do table.insert(lines, line); end
    f:close();
    return lines;
end

-- Re-read the rule file into doc and edit, reset the engine, and report any line that did not
-- parse. A missing file is an empty document.
function M.load(S)
    S.doc  = document.parse(read_lines(M.path(S)));
    S.edit = S.doc;
    S.eng  = engine.new();
    for i, r in ipairs(S.doc.rules) do
        if r.error then M.say(('%s rule %d: %s'):format(S.job, i, r.error)); end
    end
end

-- Write next_doc to the rule file and make it the saved and edited document. Returns false,
-- with the reason in the footer, if the file could not be opened.
function M.save(S, next_doc)
    ashita.fs.create_dir(DIR .. S.char);
    local f = io.open(M.path(S), 'w');
    if f == nil then M.status(S, 'Could not write ' .. M.path(S)); return false; end
    f:write(table.concat(document.lines(next_doc), '\n'), '\n');
    f:close();
    S.doc, S.edit, S.eng = next_doc, next_doc, engine.new();
    return true;
end

-- The Run switch. Turning on restarts the AFK clock; turning off forgets the action in flight.
function M.set_run(S, on)
    S.run = on;
    S.rest = afk.new(os.clock());
    if not on then S.inflight = nil; end
    M.say(on and ('Running %s rules.'):format(S.job or '') or 'Stopped.');
end

-- The shipped starting set for the job, or nil when none ships for it.
local function template(job)
    local doc = document.parse(read_lines(TEMPLATES .. job .. '.txt'));
    return #doc.rules > 0 and doc or nil;
end

-- A new character or job: load its rules and start pacing, tracking and the AFK clock afresh.
function M.switch(S, name, abbr)
    S.char, S.job = name, abbr;
    S.template = template(abbr);
    M.load(S);
    S.pace, S.track, S.inflight, S.rest = pacing.new(), tracker.new(), nil, afk.new(os.clock());
end

return M;
