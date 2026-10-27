local afk = require('lib.afk');

-- in front of the game, with or without a key press since the last tick
local function here(input)
    return { input = input == true, focused = true };
end

-- me at the keyboard but pressing nothing, sampled every second
local function settle(state, from, to, obs)
    for t = from, to do state = afk.update(state, obs or here(), t); end
    return state;
end

test('the rules sleep after one minute without a key press', function()
    assert_eq(afk.TIMEOUT, 60);
end);

test('a fresh state is awake and falls asleep once I have not pressed a key for the timeout', function()
    local s = afk.new(0);
    assert_eq(afk.asleep(s), false);
    s = settle(s, 1, afk.TIMEOUT - 1);
    assert_eq(afk.asleep(s), false, 'one second short');
    local s2, change = afk.update(s, here(), afk.TIMEOUT);
    assert_eq(afk.asleep(s2), true);
    assert_eq(change, 'asleep');
    local s3, again = afk.update(s2, here(), afk.TIMEOUT + 1);
    assert_eq(again, nil, 'the transition is reported once');
    assert_eq(afk.asleep(s3), true);
end);

test('a key press restarts the timer', function()
    local s = settle(afk.new(0), 1, 100);
    s = afk.update(s, here(true), 101);
    s = settle(s, 102, 101 + afk.TIMEOUT - 1);
    assert_eq(afk.asleep(s), false, 'the key press at 101 keeps it awake until 101 + TIMEOUT');
    s = afk.update(s, here(true), 101 + afk.TIMEOUT);
    assert_eq(afk.asleep(s), false, 'a key press at the deadline resets it again');
    s = settle(s, 102 + afk.TIMEOUT, 100 + 2 * afk.TIMEOUT);
    assert_eq(afk.asleep(s), false);
    s = afk.update(s, here(), 101 + 2 * afk.TIMEOUT);
    assert_eq(afk.asleep(s), true);
end);

test('walking, following, knockback and the party fighting are not proof I am here: only a key press is', function()
    local s = settle(afk.new(0), 1, 10);
    for t = 11, afk.TIMEOUT - 1 do
        s = afk.update(s, { input = false, focused = true, positions = { [0] = { x = t, y = 0, z = 0 } }, combat = true }, t);
    end
    assert_eq(afk.asleep(s), false, 'one second short');
    s = afk.update(s, { input = false, focused = true, positions = { [0] = { x = 999, y = 0, z = 0 } }, combat = true }, afk.TIMEOUT);
    assert_eq(afk.asleep(s), true, 'moving the whole time without a key press did not count');
    s = afk.update(s, { input = false, focused = true, positions = { [0] = { x = 1000, y = 0, z = 0 } }, combat = true }, afk.TIMEOUT + 1);
    assert_eq(afk.asleep(s), true, 'a step does not wake it either');
end);

test('asleep, a key press wakes it and restarts the full timeout', function()
    local s = settle(afk.new(0), 1, afk.TIMEOUT);
    assert_eq(afk.asleep(s), true);
    local s2, change = afk.update(s, here(true), afk.TIMEOUT + 3);
    assert_eq(afk.asleep(s2), false);
    assert_eq(change, 'awake');
    s2 = settle(s2, afk.TIMEOUT + 4, 2 * afk.TIMEOUT + 2);
    assert_eq(afk.asleep(s2), false, 'waking restarts the full timeout');
    local s3, slept = afk.update(s2, here(), 2 * afk.TIMEOUT + 3);
    assert_eq(afk.asleep(s3), true);
    assert_eq(slept, 'asleep');
end);

test('the rules are held while the game window is in the background and run again when it is in front', function()
    local s = afk.update(afk.new(0), here(), 1);
    assert_eq(afk.blocked(s), nil, 'in front and awake: nothing holds the rules');
    s = afk.update(s, { input = false, focused = false }, 2);
    assert_eq(afk.blocked(s), 'unfocused');
    assert_eq(afk.asleep(s), false, 'a background window is not sleep');
    s = afk.update(s, here(), 3);
    assert_eq(afk.blocked(s), nil, 'back in front: nothing to wake');
end);

test('the timer keeps counting while the window is in the background', function()
    local s = afk.update(afk.new(0), here(), 1);
    s = settle(s, 2, afk.TIMEOUT - 1, { input = false, focused = false });
    assert_eq(afk.blocked(s), 'unfocused', 'in the background a window is what holds the rules first');
    s = afk.update(s, { input = false, focused = false }, afk.TIMEOUT);
    assert_eq(afk.asleep(s), true, 'a minute away from the window is a minute without a key press');
    s = afk.update(s, here(), afk.TIMEOUT + 1);
    assert_eq(afk.blocked(s), 'asleep', 'coming back to the window is not a key press');
    s = afk.update(s, here(true), afk.TIMEOUT + 2);
    assert_eq(afk.blocked(s), nil);
end);

test('the rules are held until the window is seen in front: an unknown focus is a background one', function()
    assert_eq(afk.blocked(afk.new(0)), 'unfocused');
    assert_eq(afk.blocked(afk.update(afk.new(0), { input = false }, 1)), 'unfocused');
end);

test('update does not mutate the state it was given', function()
    local s = afk.new(0);
    local s2 = afk.update(s, here(true), 5);
    assert_eq(afk.blocked(s2), nil);
    assert_eq(s2.still_since, 5);
    assert_eq(afk.blocked(s), 'unfocused', 'the original has still not seen the window in front');
    assert_eq(s.still_since, 0, 'the original still has its clock');
end);

-- a keyboard window message as Ashita's key event hands it over: lparam bit 30 says the key was
-- already down (autorepeat), bit 31 says this is the release
local function key(opts)
    local lparam = 0x001E0001;
    if opts.held then lparam = lparam + 0x40000000; end
    if opts.release then lparam = lparam + 0x80000000; end
    return { wparam = 0x57, lparam = lparam, blocked = false };
end

test('only a fresh key-down is a key press: a key held down counts once, and letting go counts for nothing', function()
    assert_eq(afk.pressed(key({})), true, 'the first message of a press');
    assert_eq(afk.pressed(key({ held = true })), false, 'autorepeat while the key stays down');
    assert_eq(afk.pressed(key({ release = true })), false, 'the release');
    assert_eq(afk.pressed(key({ held = true, release = true })), false, 'a release after autorepeat');
end);

-- a controller button event as Ashita's xinput_button and dinput_button events hand it over:
-- the button and its state, nonzero while down, 0 on release
local function pad(button, state)
    return { button = button, state = state, blocked = false, injected = false };
end

test('a controller button counts once, when it goes down: holding it and letting go count for nothing', function()
    local down, fresh = afk.button({}, pad(0x1000, 1));
    assert_eq(fresh, true, 'the A button going down');
    assert_eq(down, { [0x1000] = true });
    local again;
    down, again = afk.button(down, pad(0x1000, 1));
    assert_eq(again, false, 'still down: a hold, however often the pad reports it');
    down, again = afk.button(down, pad(0x1000, 0));
    assert_eq(again, false, 'the release');
    assert_eq(down, {});
    local _, pressed_again = afk.button(down, pad(0x1000, 1));
    assert_eq(pressed_again, true, 'down again: a new press');
end);

test('each button is its own press, and a DirectInput state of 0x80 is down', function()
    local down, fresh = afk.button({ [1] = true }, pad(2, 0x80));
    assert_eq(fresh, true);
    assert_eq(down, { [1] = true, [2] = true });
    local _, held = afk.button(down, pad(1, 0x80));
    assert_eq(held, false);
end);

test('button does not change the set it was given, and a fresh press is the input the gate reads', function()
    local down = { [1] = true };
    afk.button(down, pad(1, 0));
    assert_eq(down, { [1] = true });
    local s = settle(afk.new(0), 1, afk.TIMEOUT);
    assert_eq(afk.asleep(s), true);
    local _, fresh = afk.button({}, pad(0x2000, 1));
    local s2, change = afk.update(s, { input = fresh, focused = true }, afk.TIMEOUT + 1);
    assert_eq(change, 'awake');
    assert_eq(afk.asleep(s2), false);
end);
