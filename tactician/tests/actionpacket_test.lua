local ap = require('lib.actionpacket');

-- Packs fields little-endian at the bit offsets the client uses, the mirror of the parser.
local function packet(fields)
    local bits = {};
    local function put(offset, len, value)
        for i = 0, len - 1 do
            bits[offset + i] = math.floor(value / 2 ^ i) % 2;
        end
    end
    put(0, 8, 0x28);
    put(40, 32, fields.actor);
    put(72, 10, #fields.targets);
    put(82, 4, fields.category);
    put(86, 16, fields.param or 0);
    local offset = 150;
    for _, t in ipairs(fields.targets) do
        put(offset, 32, t.id);
        put(offset + 32, 4, #t.actions);
        offset = offset + 36;
        for _, a in ipairs(t.actions) do
            put(offset + 27, 17, a.param or 0);
            put(offset + 44, 10, a.message or 0);
            put(offset + 85, 1, a.add and 1 or 0);
            offset = offset + 86;
            if a.add then offset = offset + 37; end
            put(offset, 1, a.spike and 1 or 0);
            offset = offset + 1;
            if a.spike then offset = offset + 34; end
        end
    end
    local bytes = {};
    for i = 0, math.ceil((offset + 8) / 8) do
        local v = 0;
        for b = 0, 7 do v = v + (bits[i * 8 + b] or 0) * 2 ^ b; end
        bytes[i + 1] = string.char(v);
    end
    return table.concat(bytes);
end

test('the actor, category, param and target ids come out of the packed packet', function()
    local data = packet({ actor = 0x01020304, category = 4, param = 0, targets = {
        { id = 0x00000AAA, actions = { { param = 3, message = 230 } } },
        { id = 0x00000BBB, actions = { { param = 3, message = 230, add = true }, { param = 1, spike = true } } },
    } });
    assert_eq(data:byte(6), 0x04, 'actor id is little-endian at byte 5');
    assert_eq(data:byte(9), 0x01);
    local p = ap.parse(data);
    assert_eq(p.actor, 0x01020304);
    assert_eq(p.category, 4);
    assert_eq(p.param, 0);
    assert_eq(p.targets, { 0xAAA, 0xBBB });
end);

test('my own packets become pacing events: cast start, interrupt, finish', function()
    local me = 100;
    local function ev(category, param)
        return ap.classify(ap.parse(packet({ actor = me, category = category, param = param, targets = { { id = 7, actions = {} } } })), me);
    end
    assert_eq(ev(8, 0), { kind = 'start' });
    assert_eq(ev(8, ap.INTERRUPTED), { kind = 'interrupt' });
    assert_eq(ev(4, 0), { kind = 'finish' });
    assert_eq(ev(6, 0), { kind = 'finish' });
    assert_eq(ev(3, 0), { kind = 'finish' });
    assert_eq(ev(2, 0), { kind = 'finish' });
    assert_eq(ev(5, 0), { kind = 'finish' });
    assert_eq(ev(12, 0), { kind = 'start' });
    assert_eq(ev(9, 0), { kind = 'start' });
    assert_eq(ev(1, 0), nil, 'a melee swing is not an action I queued');
end);

test('somebody else\'s packets are not my events', function()
    local p = ap.parse(packet({ actor = 500, category = 4, targets = { { id = 100, actions = {} } } }));
    assert_eq(ap.classify(p, 100), nil);
end);

test('a packet that is not an action packet parses to nothing', function()
    assert_eq(ap.parse(string.char(0x17, 0, 0, 0)), nil);
    assert_eq(ap.parse(''), nil);
end);
