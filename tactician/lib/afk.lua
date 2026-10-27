-- The attended-use gate: the rules sleep once I have not pressed a key for TIMEOUT seconds,
-- and only a key press wakes them. Walking, /follow, knockback and the party fighting count
-- for nothing either way: a mob claim or a change of position is not proof a human is here, a
-- keystroke is, so the gate reads only what a human at this keyboard produces. The rules are
-- also held, without sleeping, while the game window is not the one in front: a window in the
-- background cannot be the one its player is attending to. Pure; the entry point feeds it
-- whether a key was pressed since the last tick, whether the window is in front, and the clock.
local M = {};

M.TIMEOUT = 60;  -- seconds

-- focused is nil until the first tick says where the window is, so that tick is not a return
-- to the window.
function M.new(now)
    return { still_since = now, asleep = false, focused = nil };
end

function M.asleep(state)
    return state.asleep == true;
end

-- Whether a keyboard window message, as Ashita's key event hands it over, is a fresh press: not
-- the autorepeat of a key held down (lparam bit 30) and not its release (bit 31). A key held down
-- counts once, so a weight on a key is not a hand on the keyboard.
local KEY_WAS_DOWN   = 0x40000000;
local KEY_RELEASED   = 0x80000000;
function M.pressed(e)
    return bit.band(e.lparam, KEY_WAS_DOWN) == 0 and bit.band(e.lparam, KEY_RELEASED) == 0;
end

-- Why the rules may not fire right now: 'unfocused', 'asleep', or nil when they may.
function M.blocked(state)
    if state.focused ~= true then return 'unfocused'; end
    if state.asleep then return 'asleep'; end
    return nil;
end

-- The one word for what the rules are doing, Run switch included: 'off', 'unfocused', 'asleep'
-- or 'running'. The editor banner and /tactician status both say WHY[state].
function M.state(run, state)
    if not run then return 'off'; end
    return M.blocked(state) or 'running';
end

-- What to tell the player for each state, with what to do about it.
M.WHY = {
    off       = 'Rules off. /tactician on to start.',
    unfocused = 'Paused: the game window is not in front.',
    asleep    = ('Asleep: no key press from you for %d seconds. Press a key to wake the rules.'):format(M.TIMEOUT),
    running   = 'Running.',
};

-- The chat line for a change update reported, said once on the tick it happens.
function M.line(change, state)
    if change == 'asleep' then return M.WHY.asleep; end
    if change == 'awake' then return 'You are back. Rules awake.'; end
    if change == 'paused' then return M.WHY.unfocused; end
    if state.asleep then return 'Game window in front again, but the rules are asleep: press a key to wake them.'; end
    return 'Game window in front again. Rules running.';
end

-- obs = { input = bool, focused = bool }. Returns the new state and, on the tick it changes,
-- 'asleep' or 'awake' for the key-press gate, else 'paused' or 'focused' for the window.
function M.update(state, obs, now)
    local present = obs.input == true;
    local focused = obs.focused == true;
    local out = { still_since = state.still_since, asleep = state.asleep, focused = focused };
    if state.asleep then
        if present then out.asleep, out.still_since = false, now; return out, 'awake'; end
    elseif present then
        out.still_since = now;
    elseif now - state.still_since >= M.TIMEOUT then
        out.asleep = true;
        return out, 'asleep';
    end
    if state.focused == true and not focused then return out, 'paused'; end
    if state.focused == false and focused then return out, 'focused'; end
    return out;
end

return M;
