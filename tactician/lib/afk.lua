-- The attended-use gate: the rules sleep once I have not pressed a key for TIMEOUT seconds,
-- and only a key press wakes them. Walking, /follow, knockback and the party fighting count
-- for nothing either way: a mob claim or a change of position is not proof a human is here, a
-- keystroke is, so the gate reads only what a human at this keyboard produces. The rules are
-- also held, without sleeping, while the game window is not the one in front: a window in the
-- background cannot be the one its player is attending to. Pure; the entry point feeds it
-- whether a key was pressed since the last tick, whether the window is in front, and the clock.
local M = {};

M.TIMEOUT = 60;  -- seconds

function M.new(now)
    return { still_since = now, asleep = false, focused = false };
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

-- obs = { input = bool, focused = bool }. Returns the new state and 'asleep' or 'awake' on
-- the tick it changes.
function M.update(state, obs, now)
    local present = obs.input == true;
    local out = { still_since = state.still_since, asleep = state.asleep, focused = obs.focused == true };
    if state.asleep then
        if present then out.asleep, out.still_since = false, now; return out, 'awake'; end
        return out;
    end
    if present then
        out.still_since = now;
    elseif now - state.still_since >= M.TIMEOUT then
        out.asleep = true;
        return out, 'asleep';
    end
    return out;
end

return M;
