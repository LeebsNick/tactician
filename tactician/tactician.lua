--[[
* tactician - A player-authored combat rules system for CatsEyeXI. Gambits for your own
* character, the way CatsEyeXI's trusts run theirs: an ordered list of scope / if / then lines
* per job, read top down every third of a second, the first one that fits sent as the slash
* command you would have typed. Cures, buffs, stuns,
* weapon skills, ranged attacks and items; nothing it does is beyond what your character can
* do by hand, and nothing here touches trusts or other players. It is built to stay an attended
* helper: it never engages, anything aimed at the monster waits until you have engaged it
* yourself, the rules hold while the game window is not the one in front, and they fall asleep
* after a minute without a key press from you, waking only when you press one.
*
* Rules live in config/addons/tactician/<character>/<JOB>.txt, one per line:
*   party hpp_lt:50 ma:highest:Cure
*   self not_status:Protect ma:highest:Protect retry:10
*   target casting_ma ma:Stun
*   self tp_gte:1000 ws:"Fast Blade"
*
* Commands:
*   /tactician                 - toggle the editor window
*   /tactician on|off          - start or stop running the rules (off at load, always)
*   /tactician list            - print this job's rules
*   /tactician add <rule>      - append a rule, e.g. /tactician add party hpp_lt:50 ma:highest:Cure
*   /tactician del <n>         - delete rule n
*   /tactician move <n> <m>    - move rule n to position m
*   /tactician toggle <n>      - switch rule n on or off
*   /tactician reload          - re-read the file
*   /tactician status          - what the engine is doing
*
* This file is the driver: it owns the one state table S (lib/session), runs the tick that reads
* the client and sends a command, and registers the five Ashita events. Each surface is its own
* module in lib/:
*   session    the state table and the moves every surface shares (load, save, run, switch)
*   resources  the DATs, bags and party status icons read into plain tables
*   commands   the /tactician slash commands
*   editor     the ImGui window
* Pure logic (rules, catalog, engine, pacing, afk, ...) is the rest of lib/, covered by tests/
* (from the repo root: luajit tests/run.lua tactician). Ashita only: it reads the client through
* the memory manager.
--]]

addon.name    = 'tactician';
addon.author  = 'nick';
addon.version = '1.1.1'; -- x-release-please-version
addon.desc    = 'A player-authored combat rules system for CatsEyeXI, inspired by Final Fantasy XII gambits.';

require('common');
local ffi          = require('ffi');
local actionpacket = require('lib.actionpacket');
local actions      = require('lib.actions');
local afk          = require('lib.afk');
local catalog      = require('lib.catalog');
local client       = require('lib.client');
local commands     = require('lib.commands');
local cost         = require('lib.cost');
local editor       = require('lib.editor');
local engine       = require('lib.engine');
local pacing       = require('lib.pacing');
local resources    = require('lib.resources');
local session      = require('lib.session');
local tracker      = require('lib.tracker');

local TICK           = 0.3;    -- seconds between reads of the client
local REFRESH        = 5;      -- seconds between re-reads of what is learned and what is in the bags
local PACKET_ACTION  = 0x028;  -- an action: someone starts, finishes or is interrupted in something
local PACKET_ZONE    = 0x00A;  -- a zone change: nothing in flight survives it

-- Everything the addon tracks lives in this one table; lib/session lists the fields.
local S = session.new();

-- A fine clock for the frame-cost meters; os.clock stays the tick's clock.
local clock = cost.clock();

-- Whether this character's game window is the one in front. AshitaCore can set the foreground
-- window but not read it, so user32 answers through FFI; the handle to compare against is the
-- one Ashita stored, a number, cast to a pointer the way the stock move addon does. Another
-- window in front, this one's or another character's, holds the rules (lib/afk).
ffi.cdef('void* GetForegroundWindow();');
local function focused()
    return ffi.C.GetForegroundWindow() == ffi.cast('void*', AshitaCore:GetProperties():GetFinalFantasyHwnd());
end

------------------------------------------------------------------------------
-- the client's own lists: the DATs once, the bags and learned sets every REFRESH seconds
------------------------------------------------------------------------------
local function refresh(mm, now)
    -- the DATs do not change while the client runs; a failed read leaves empty lists and a note
    if S.static == nil then
        local ok, data = pcall(resources.static);
        if ok then
            S.static = data;
        else
            session.status(S, 'Could not read the spell lists: ' .. tostring(data));
            S.static = { spells = {}, abilities = {}, weaponskills = {}, statuses = {} };
        end
    end
    -- the catalog indexes the DAT lists plus what is in the bags now; known is what this job can use
    local data = { spells = S.static.spells, abilities = S.static.abilities, weaponskills = S.static.weaponskills,
                   statuses = S.static.statuses, items = resources.items(mm) };
    S.cat       = catalog.build(data);
    S.known     = client.known({ player = mm:GetPlayer() }, S.cat);
    S.picks     = {};
    S.refreshed = now;
end

------------------------------------------------------------------------------
-- the tick: read, pace, pick, send
------------------------------------------------------------------------------
-- what lib/afk watches: whether I pressed a key since the last tick, and whether this window is in front
local function presence(input)
    return { input = input, focused = focused() };
end

-- One tick, every TICK seconds from d3d_present:
--   1. who am I: character and main job; a change swaps the rule file
--   2. refresh the catalog every REFRESH seconds
--   3. snapshot the client: me, party, target, recasts, bags (lib/client)
--   4. settle the action in flight (lib/pacing); a refused one backs its rule off
--   5. if running, in front and awake, pick the first rule that fits (lib/engine) and send its
--      command; a change of state (asleep, awake, paused, in front again) is said once in chat
local function tick(now)
    if now - S.last_tick < TICK then return; end
    S.last_tick = now;

    -- 1. who am I; nothing to do while zoning or before the party list has a name
    local mm     = AshitaCore:GetMemoryManager();
    local party  = mm:GetParty();
    local player = mm:GetPlayer();
    local name   = party:GetMemberName(0);
    local abbr   = actions.JOBS[player:GetMainJob()];
    if name == nil or name == '' or abbr == nil or player:GetIsZoning() ~= 0 then return; end
    -- a new job casts other spells and has other abilities: the catalog, what is learned and the
    -- pick lists are rebuilt this tick rather than within REFRESH seconds
    if name ~= S.char or abbr ~= S.job then session.switch(S, name, abbr); S.cat = nil; end

    -- 2. the catalog
    if S.cat == nil or now - S.refreshed >= REFRESH then refresh(mm, now); end

    -- 3. the snapshot: the manager objects lib/client reads, plus what only this file knows
    local mmt = { party = party, player = player, entity = mm:GetEntity(), target = mm:GetTarget(),
                  recast = mm:GetRecast(), inventory = mm:GetInventory() };
    S.track = tracker.prune(S.track, now);
    local tidx = mmt.target:GetTargetIndex(0);
    local tid  = (tidx ~= nil and tidx ~= 0) and mmt.entity:GetServerId(tidx) or 0;
    local extras = { now = now, party_buffs = resources.party_buffs(), known = S.known, tracker = tracker.flags(S.track, tid, now),
                     ws_age = function(id) return tracker.ws_age(S.track, id, now); end };
    S.snap = client.snapshot(mmt, S.cat, extras);

    -- 4. the action in flight: 'refused' means the client never started it (recast, range, silence)
    local outcome;
    S.pace, outcome = pacing.step(S.pace, now);
    if outcome == 'refused' and S.inflight then
        S.eng = engine.refused(S.eng, S.inflight.index, now);
        S.ui.last = ('%d. %s: not accepted, resting %ds'):format(S.inflight.index, S.inflight.command, engine.BACKOFF);
    end
    if outcome then S.inflight = nil; end

    -- 5. pick and send, only while running, in front, awake, idle, and alive
    if not S.run then return; end
    local change;
    S.rest, change = afk.update(S.rest, presence(S.input), now);
    S.input = false;
    if change then session.say(afk.line(change, S.rest)); end
    if afk.blocked(S.rest) or not pacing.ready(S.pace) then return; end
    if S.snap.me.status == 'dead' or S.snap.me.status == 'event' then return; end
    local fire = engine.pick(S.doc, S.cat, S.snap, S.eng);
    if fire == nil then return; end
    AshitaCore:GetChatManager():QueueCommand(1, fire.command);
    S.pace, S.eng, S.inflight = pacing.send(S.pace, fire.action, now), engine.fired(S.eng, fire.index, now), fire;
    S.ui.last = ('%d. %s'):format(fire.index, fire.command);
end

-- Incoming packets feed two things: lib/tracker learns what the target is doing, and whose
-- weapon skill landed, from every action packet, and lib/pacing learns whether my own action
-- started, finished or was cut short.
ashita.events.register('packet_in', 'packet_in_cb', function(e)
    if e.id == PACKET_ZONE then
        S.pace, S.track, S.inflight = pacing.new(), tracker.new(), nil;
        return;
    end
    if e.id ~= PACKET_ACTION then return; end
    local p = actionpacket.parse(e.data);
    if p == nil then return; end
    local now = os.clock();
    S.track = tracker.observe(S.track, p, now);
    local ev = actionpacket.classify(p, S.snap and S.snap.me.id or AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0));
    if ev == nil then return; end
    local outcome;
    S.pace, outcome = pacing.event(S.pace, ev, now);
    if outcome == 'interrupted' then S.ui.last = S.ui.last .. ' (interrupted)'; end
    if pacing.ready(S.pace) then S.inflight = nil; end
end);

-- /tactician and its sub-commands: lib/commands
ashita.events.register('command', 'command_cb', function(e) commands.handle(S, e); end);

-- A key press is the one thing only a human at this keyboard produces; lib/afk reads it on
-- the next tick. Only the first message of a press counts: a key held down repeats and then
-- releases, and neither is a new press. The addon's own commands never pass through here.
ashita.events.register('key', 'key_cb', function(e)
    if afk.pressed(e) then S.input = true; end
end);

-- Every frame: the tick, then the editor window (lib/editor), each timed into lib/cost so
-- /tactician status and the editor header show what the addon takes of the frame. A tick error
-- is printed once; a second spent over budget is said once.
ashita.events.register('d3d_present', 'present_cb', function()
    local t0 = clock();
    local ok, err = pcall(tick, os.clock());
    if not ok and not S.reported then
        S.reported = true;
        session.say('Error: ' .. tostring(err));
    end
    local t1 = clock();
    editor.draw(S);
    local t2 = clock();
    S.cost.tick = cost.add(S.cost.tick, t1 - t0, t0);
    S.cost.draw = cost.add(S.cost.draw, t2 - t1, t0);
    if not S.warned and (cost.heavy(S.cost.tick) or cost.heavy(S.cost.draw)) then
        S.warned = true;
        session.say(('Heavy frame: tick %s; editor %s. /tactician status shows it live.'):format(cost.text(S.cost.tick), cost.text(S.cost.draw)));
    end
end);

ashita.events.register('load', 'load_cb', function()
    session.say('/tactician opens the editor; /tactician on starts the rules. They are off until you say so.');
end);
