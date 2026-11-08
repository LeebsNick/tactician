-- Which controller messages are a fresh button press, under the same restrictions lib/afk puts
-- on the keyboard: a button counts once, when it goes down; its release and a button held down
-- count for nothing; sticks, triggers and other axes count for nothing, since a stick is
-- walking and camera and a drifting stick is not a hand; and input injected by Ashita or
-- another addon counts for nothing, since only a human at the pad produces a press. Pure; the
-- entry point feeds it each xinput_button and dinput_button event as Ashita hands it over.
local M = {};

-- XInput ids 0 to 15 are the digital buttons (d-pad, Menu, View, L3, R3, L1, R1, A, B, X, Y);
-- the ids above them are the two triggers and the four stick axes.
M.XINPUT_BUTTONS = 16;

-- A DirectInput event's button is the object's offset in the joystick state: the axes and
-- sliders come first, then four hats from 32, then the buttons from 48. A hat reads its angle
-- in hundredths of a degree, or -1 when centred; some drivers report centre as 0xFFFF in the
-- low word instead. A button reads 0x80 while down.
M.DINPUT_HAT     = 32;
M.DINPUT_BUTTON  = 48;
local HAT_CENTRED = 0xFFFF;
local BUTTON_DOWN = 0x80;

local function xinput_down(e)
    if e.button >= M.XINPUT_BUTTONS then return nil; end
    return e.state ~= 0;
end

local function dinput_down(e)
    if e.button < M.DINPUT_HAT then return nil; end
    if e.button < M.DINPUT_BUTTON then return bit.band(e.state, HAT_CENTRED) ~= HAT_CENTRED; end
    return bit.band(e.state, BUTTON_DOWN) ~= 0;
end

local READ = { xinput = xinput_down, dinput = dinput_down };

-- Whether the event is a button going down (true), a button going up (false), or no button at
-- all (nil): an axis, or input a human did not produce.
function M.down(device, e)
    if e.injected == true then return nil; end
    return READ[device](e);
end

-- What is held, by device and button id.
function M.new()
    return { xinput = {}, dinput = {} };
end

local function with(held, id, down)
    local out = {};
    for k, v in pairs(held) do out[k] = v; end
    out[id] = down or nil;
    return out;
end

-- Returns the new state and whether this event is a fresh press: a button going down that was
-- not already held.
function M.update(state, device, e)
    local down = M.down(device, e);
    if down == nil then return state, false; end
    local fresh = down and not state[device][e.button];
    local out = { xinput = state.xinput, dinput = state.dinput };
    out[device] = with(state[device], e.button, down);
    return out, fresh;
end

return M;
