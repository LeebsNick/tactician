-- What other actors are doing, from their action packets: a monster that started casting
-- (category 8) is casting until it finishes (4), is interrupted, or the window closes; one
-- that readied a TP move (7) is readying until it lands (11) or the window closes. The
-- server does not tell the client when a cast is still going, so the windows are the cap.
local M = {};

M.CAST_WINDOW  = 6;
M.READY_WINDOW = 4;
M.INTERRUPTED  = 28787;

function M.new()
    return {};
end

local function copy(t)
    local out = {};
    for k, v in pairs(t) do out[k] = v; end
    return out;
end

-- p: a parsed action packet (lib/actionpacket). Returns a new table.
function M.observe(t, p, now)
    local c = p.category;
    if c ~= 8 and c ~= 7 and c ~= 4 and c ~= 11 then return t; end
    local old = t[p.actor] or {};
    local e   = { casting_until = old.casting_until, readying_until = old.readying_until };
    if c == 8 then
        if p.param == M.INTERRUPTED then e.casting_until = nil; else e.casting_until = now + M.CAST_WINDOW; end
    elseif c == 4 then
        e.casting_until = nil;
    elseif c == 7 then
        e.readying_until = now + M.READY_WINDOW;
    else
        e.readying_until = nil;
    end
    local out = copy(t);
    if e.casting_until == nil and e.readying_until == nil then out[p.actor] = nil; else out[p.actor] = e; end
    return out;
end

function M.flags(t, id, now)
    local e = t[id];
    return {
        casting  = e ~= nil and e.casting_until ~= nil and now < e.casting_until,
        readying = e ~= nil and e.readying_until ~= nil and now < e.readying_until,
    };
end

function M.prune(t, now)
    local out = {};
    for id, e in pairs(t) do
        local f = M.flags(t, id, now);
        if f.casting or f.readying then out[id] = e; end
    end
    return out;
end

return M;
