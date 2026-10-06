-- What the addon spends of each frame, so /tactician status and the editor header can show that
-- the rules are cheap next to Ashita's own frame-cost tools. One meter per bucket (the tick,
-- the editor window): add folds a frame's seconds in, and every WINDOW seconds the mean and
-- the worst frame roll over into what text and heavy report. Pure; the caller brings the clock.
local M = {};

M.WINDOW = 1;      -- seconds one sample covers
M.BUDGET = 0.002;  -- mean seconds per frame past which a bucket counts as heavy: 2 ms of a 16.7 ms frame

function M.new(now)
    return { since = now, total = 0, frames = 0, worst = 0, mean = 0, peak = 0 };
end

function M.add(c, spent, now)
    local n = { since = c.since, total = c.total + spent, frames = c.frames + 1,
                worst = math.max(c.worst, spent), mean = c.mean, peak = c.peak };
    if now - c.since >= M.WINDOW then
        n.mean, n.peak = n.total / n.frames, n.worst;
        n.since, n.total, n.frames, n.worst = now, 0, 0, 0;
    end
    return n;
end

function M.heavy(c)
    return c.mean > M.BUDGET;
end

function M.text(c)
    return ('%.2f ms/frame, worst %.1f ms'):format(c.mean * 1000, c.peak * 1000);
end

-- A clock fine enough for sub-millisecond frames: QueryPerformanceCounter through LuaJIT's ffi
-- on Windows, os.clock (a millisecond at best) anywhere that fails, such as the test run.
function M.clock()
    local ok, ffi = pcall(require, 'ffi');
    if not ok then return os.clock; end
    local good, tick = pcall(function()
        ffi.cdef[[
            int __stdcall QueryPerformanceFrequency(int64_t* f);
            int __stdcall QueryPerformanceCounter(int64_t* c);
        ]];
        local f, c = ffi.new('int64_t[1]'), ffi.new('int64_t[1]');
        ffi.C.QueryPerformanceFrequency(f);
        local hz = tonumber(f[0]);
        return function()
            ffi.C.QueryPerformanceCounter(c);
            return tonumber(c[0]) / hz;
        end;
    end);
    return good and tick or os.clock;
end

return M;
