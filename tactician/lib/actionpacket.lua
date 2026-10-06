-- The incoming action packet (0x028): who did what, bit-packed little-endian from the first
-- byte of the packet. Only the header and the target ids are read; the parse walks each
-- action block so later targets land at the right offset.
local M = {};

M.INTERRUPTED = 28787;  -- header param of a category 8 packet whose cast was interrupted

-- categories that mean I started something, and that mean it landed or finished
M.START  = { [8] = true, [9] = true, [12] = true };
M.FINISH = { [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [14] = true, [15] = true };

local function bits(data, offset, len)
    local value = 0;
    for i = 0, len - 1 do
        local pos  = offset + i;
        local byte = data:byte(math.floor(pos / 8) + 1) or 0;
        if bit.band(bit.rshift(byte, pos % 8), 1) == 1 then value = value + 2 ^ i; end
    end
    return value;
end

-- { actor, category, param, targets = { id, ... } } or nil for any other packet
function M.parse(data)
    if type(data) ~= 'string' or #data < 19 or data:byte(1) ~= 0x28 then return nil; end
    local p = { actor = bits(data, 40, 32), category = bits(data, 82, 4), param = bits(data, 86, 16), targets = {} };
    local count  = bits(data, 72, 10);
    local offset = 150;
    for _ = 1, count do
        if offset + 36 > #data * 8 then break; end
        table.insert(p.targets, bits(data, offset, 32));
        local n = bits(data, offset + 32, 4);
        offset = offset + 36;
        for _ = 1, n do
            local add = bits(data, offset + 85, 1);
            offset = offset + 86;
            if add == 1 then offset = offset + 37; end
            local spike = bits(data, offset, 1);
            offset = offset + 1;
            if spike == 1 then offset = offset + 34; end
        end
    end
    return p;
end

-- A pacing event when the packet is about my own action, else nil.
function M.classify(p, me)
    if p == nil or p.actor ~= me then return nil; end
    if p.category == 8 and p.param == M.INTERRUPTED then return { kind = 'interrupt' }; end
    if M.START[p.category] then return { kind = 'start' }; end
    if M.FINISH[p.category] then return { kind = 'finish' }; end
    return nil;
end

return M;
