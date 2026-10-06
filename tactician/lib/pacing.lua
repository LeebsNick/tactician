-- One action in flight at a time. A sent command waits for the game to acknowledge it with an
-- action packet: a cast start keeps the pacer busy for the cast time, a finish or interrupt
-- frees it, and silence means the game refused the command (out of range, silenced, no line
-- of sight), which the engine answers by backing that rule off. Pure; the entry point feeds
-- it the clock and the packets.
local M = {};

M.START_TIMEOUT = 1.5;  -- seconds for the game to acknowledge a sent command
M.GRACE         = 2;    -- seconds past the cast time before a cast is given up on
M.INSTANT       = 1.5;  -- busy window for an action that starts but has no cast time

function M.new()
    return { phase = 'idle' };
end

function M.ready(p)
    return p.phase == 'idle';
end

function M.send(_, action, now)
    return { phase = 'sent', at = now, action = action };
end

-- ev.kind: 'start', 'finish' or 'interrupt' (from lib/actionpacket). Returns the new state
-- and, for an interrupt, the word 'interrupted'.
function M.event(p, ev, now)
    if p.phase == 'idle' then return p; end
    if ev.kind == 'start' then
        return { phase = 'busy', at = now, done_at = now + (p.action.cast or M.INSTANT), action = p.action };
    end
    if ev.kind == 'finish' then return M.new(); end
    if ev.kind == 'interrupt' then return M.new(), 'interrupted'; end
    return p;
end

-- Advances the clock: the new state and 'refused' or 'timeout' when a wait ran out.
function M.step(p, now)
    if p.phase == 'sent' and now - p.at >= M.START_TIMEOUT then return M.new(), 'refused'; end
    if p.phase == 'busy' and now >= p.done_at + M.GRACE then return M.new(), 'timeout'; end
    return p, nil;
end

return M;
