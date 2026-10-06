-- The attended-use gate: the rules sleep once I have neither moved nor pressed a key for
-- TIMEOUT seconds, and only my own movement or key press wakes them. The party walking or
-- fighting counts for nothing either way: a mob claim is not proof a human is here, a step or
-- a keystroke is, so the gate reads only what a human at this keyboard produces. Pure; the
-- entry point feeds it my position, whether a key was pressed since the last tick, and the
-- clock. Slot 0 of positions is me; other slots are carried for the editor and ignored here.
local M = {};

M.TIMEOUT = 600;  -- seconds

function M.new(now)
    return { positions = {}, still_since = now, asleep = false };
end

function M.asleep(state)
    return state.asleep == true;
end

local function stepped(last, pos)
    return last ~= nil and pos ~= nil and (pos.x ~= last.x or pos.y ~= last.y or pos.z ~= last.z);
end

-- obs = { positions = { [slot] = { x, y, z } }, input = bool }. Returns the new state and
-- 'asleep' or 'awake' on the tick it changes.
function M.update(state, obs, now)
    local present = obs.input == true or stepped(state.positions[0], obs.positions[0]);
    local out = { positions = obs.positions, still_since = state.still_since, asleep = state.asleep };
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
