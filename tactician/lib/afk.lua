-- The attended-use gate: the rules sleep once I have not pressed a key or a controller button
-- for TIMEOUT seconds, and only such a press wakes them. Walking, /follow, knockback and the
-- party fighting count for nothing either way: a mob claim or a change of position is not proof
-- a human is here, a keystroke or a button press is, so the gate reads only what a human at
-- this keyboard or pad produces. The rules are also held, without sleeping, while the game
-- window is not the one in front: a window in the background cannot be the one its player is
-- attending to. Pure; the entry point feeds it whether a key or button was pressed since the
-- last tick, whether the window is in front, and the clock.
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

-- A controller button going down, once per press. Ashita's xinput_button and dinput_button
-- events carry the button and its state, nonzero while it is down and 0 on release, so down is
-- the set of buttons held: a button already in it is a hold, not a press, however often the pad
-- reports it, and letting go is nothing. Sticks are axes and raise no button event, so steering
-- the camera counts for nothing, like walking. Returns the new set and whether this is a press.
function M.button(down, e)
    local is  = (e.state or 0) ~= 0;
    local out = {};
    for k, v in pairs(down) do out[k] = v; end
    out[e.button] = is or nil;
    return out, is and down[e.button] ~= true;
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
