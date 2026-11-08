local pad = require('lib.pad');

-- an xinput_button event as Ashita hands it over: ids 0 to 15 are the digital buttons, state 1
-- down and 0 up; 16 and up are the triggers and sticks, state the analog reading
local function xbutton(id, down, opts)
    return { button = id, state = down and 1 or 0, blocked = false, injected = opts and opts.injected or false };
end
local function xaxis(id, value)
    return { button = id, state = value, blocked = false, injected = false };
end

-- a dinput_button event: button is the DirectInput object offset, state the object's data
local DI_BUTTON0, DI_POV0, DI_LX, DI_LZ = 48, 32, 0, 8;
local function dbutton(n, down, opts)
    return { button = DI_BUTTON0 + n, state = down and 0x80 or 0, blocked = false, injected = opts and opts.injected or false };
end
local function dobject(offset, value)
    return { button = offset, state = value, blocked = false, injected = false };
end

local function presses(device, events)
    local s, count = pad.new(), 0;
    for _, e in ipairs(events) do
        local fresh;
        s, fresh = pad.update(s, device, e);
        if fresh then count = count + 1; end
    end
    return count;
end

test('a controller button going down is a press; letting go counts for nothing', function()
    local s, fresh = pad.update(pad.new(), 'xinput', xbutton(12, true));
    assert_eq(fresh, true, 'A down');
    local _, release = pad.update(s, 'xinput', xbutton(12, false));
    assert_eq(release, false, 'A up');
    assert_eq(presses('dinput', { dbutton(1, true) }), 1, 'Cross down');
    assert_eq(presses('dinput', { dbutton(1, true), dbutton(1, false) }), 1, 'Cross up counts for nothing');
end);

test('a button held down counts once, when it goes down, and again only after it is let go', function()
    assert_eq(presses('xinput', { xbutton(0, true), xbutton(0, true), xbutton(0, true) }), 1, 'held XInput d-pad up');
    assert_eq(presses('dinput', { dbutton(0, true), dbutton(0, true) }), 1, 'held Square');
    assert_eq(presses('xinput', { xbutton(0, true), xbutton(0, false), xbutton(0, true) }), 2, 'down, up, down');
    assert_eq(presses('dinput', { dbutton(0, true), dbutton(0, false), dbutton(0, true) }), 2, 'the first DirectInput button, down, up, down');
    assert_eq(presses('xinput', { xbutton(15, true), xbutton(15, false), xbutton(15, true) }), 2, 'Y, the last XInput button, down, up, down');
    assert_eq(presses('xinput', { xbutton(0, true), xbutton(1, true) }), 2, 'two different buttons are two presses');
end);

test('sticks and triggers count for nothing, however far they move: a stick is walking, and a drifting stick is not a hand', function()
    local current = { xaxis(16, 255), xaxis(17, 255), xaxis(18, 32767), xaxis(19, -32768), xaxis(20, 100), xaxis(21, -100) };
    assert_eq(presses('xinput', current), 0, 'XInput triggers and sticks on the current interface');
    assert_eq(presses('xinput', { xaxis(32, 255), xaxis(34, 32767), xaxis(37, -32768) }), 0, 'and on the older one');
    local axes = { dobject(DI_LX, 65535), dobject(4, 0), dobject(DI_LZ, 32767), dobject(12, 255), dobject(16, 255), dobject(20, 0),
                   dobject(24, 1), dobject(28, 1) };
    assert_eq(presses('dinput', axes), 0, 'DirectInput axes and sliders');
end);

test('the DirectInput hat is a button: leaving centre is one press, moving round while held is not, and coming back is nothing', function()
    assert_eq(presses('dinput', { dobject(DI_POV0, 0) }), 1, 'up');
    assert_eq(presses('dinput', { dobject(DI_POV0, 0), dobject(DI_POV0, 4500), dobject(DI_POV0, 9000) }), 1, 'rolled from up to right while held');
    assert_eq(presses('dinput', { dobject(DI_POV0, 18000), dobject(DI_POV0, -1) }), 1, 'back to centre');
    assert_eq(presses('dinput', { dobject(DI_POV0, 18000), dobject(DI_POV0, -1), dobject(DI_POV0, 27000) }), 2, 'and pressed again');
    assert_eq(presses('dinput', { dobject(DI_POV0, 65535) }), 0, 'a driver that reports centre as 0xFFFF');
    assert_eq(presses('dinput', { dobject(DI_POV0, 0xFFFFFFFF) }), 0, 'or as the unsigned -1');
    assert_eq(presses('dinput', { dobject(36, 9000) }), 1, 'a second hat is a button too');
end);

test('a press injected by Ashita or another addon counts for nothing: only a human at the pad produces one', function()
    assert_eq(presses('xinput', { xbutton(12, true, { injected = true }) }), 0);
    assert_eq(presses('dinput', { dbutton(1, true, { injected = true }) }), 0);
end);

test('a button another addon blocked was still pressed by a human', function()
    local e = xbutton(12, true);
    e.blocked = true;
    assert_eq(presses('xinput', { e }), 1);
end);

test('each device keeps its own held buttons', function()
    local s = pad.new();
    local fresh;
    s, fresh = pad.update(s, 'xinput', xaxis(48, 1));
    assert_eq(fresh, false, 'XInput 48 is an axis');
    local _, pressed = pad.update(s, 'dinput', dbutton(0, true));
    assert_eq(pressed, true, 'DirectInput 48 is a button, not held by the XInput reading');
end);

test('update does not mutate the state it was given', function()
    local s = pad.new();
    local s2, fresh = pad.update(s, 'xinput', xbutton(3, true));
    assert_eq(fresh, true);
    local _, again = pad.update(s, 'xinput', xbutton(3, true));
    assert_eq(again, true, 'the original still has nothing held');
    local _, held = pad.update(s2, 'xinput', xbutton(3, true));
    assert_eq(held, false);
end);
