-- The attended-use gate: the rules sleep once I have not pressed a key for TIMEOUT seconds,
-- and only a key press wakes them. Walking, /follow, knockback and the party fighting count
-- for nothing either way: a mob claim or a change of position is not proof a human is here, a
-- keystroke is, so the gate reads only what a human at this keyboard produces. Pure; the entry
-- point feeds it whether a key was pressed since the last tick and the clock.
local M = {};

M.TIMEOUT = 60;  -- seconds

function M.new(now)
    return { still_since = now, asleep = false };
end

function M.asleep(state)
    return state.asleep == true;
end

-- obs = { input = bool }. Returns the new state and 'asleep' or 'awake' on
-- the tick it changes.
function M.update(state, obs, now)
    local present = obs.input == true;
    local out = { still_since = state.still_since, asleep = state.asleep };
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
