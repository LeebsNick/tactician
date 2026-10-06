local afk = require('lib.afk');

local STILL = { [0] = { x = 1, y = 2, z = 3 }, [1] = { x = 10, y = 20, z = 30 } };
local function moved(slot, pos)
    local out = {};
    for k, v in pairs(STILL) do out[k] = v; end
    out[slot] = pos;
    return out;
end

-- me standing still (where I am, or at `at`) with no key pressed, sampled every second
local function settle(state, from, to, at)
    for t = from, to do state = afk.update(state, { positions = at or STILL, combat = false, input = false }, t); end
    return state;
end

test('a fresh state is awake and falls asleep once I have neither moved nor pressed a key for the timeout', function()
    local s = afk.new(0);
    assert_eq(afk.asleep(s), false);
    s = settle(s, 1, afk.TIMEOUT - 1);
    assert_eq(afk.asleep(s), false, 'one second short');
    local s2, change = afk.update(s, { positions = STILL, combat = false, input = false }, afk.TIMEOUT);
    assert_eq(afk.asleep(s2), true);
    assert_eq(change, 'asleep');
    local s3, again = afk.update(s2, { positions = STILL, combat = false, input = false }, afk.TIMEOUT + 1);
    assert_eq(again, nil, 'the transition is reported once');
    assert_eq(afk.asleep(s3), true);
end);

test('my own step or key press restarts the timer', function()
    local s = settle(afk.new(0), 1, 100);
    s = afk.update(s, { positions = moved(0, { x = 1.5, y = 2, z = 3 }), combat = false, input = false }, 101);
    s = settle(s, 102, 101 + afk.TIMEOUT - 1, moved(0, { x = 1.5, y = 2, z = 3 }));
    assert_eq(afk.asleep(s), false, 'my step at 101 keeps it awake until 101 + TIMEOUT');
    s = afk.update(s, { positions = moved(0, { x = 1.5, y = 2, z = 3 }), combat = false, input = true }, 101 + afk.TIMEOUT);
    assert_eq(afk.asleep(s), false, 'a key press at the deadline resets it again');
    s = settle(s, 102 + afk.TIMEOUT, 100 + 2 * afk.TIMEOUT, moved(0, { x = 1.5, y = 2, z = 3 }));
    assert_eq(afk.asleep(s), false);
    s = afk.update(s, { positions = moved(0, { x = 1.5, y = 2, z = 3 }), combat = false, input = false }, 101 + 2 * afk.TIMEOUT);
    assert_eq(afk.asleep(s), true);
end);

test('the party walking or fighting is not proof I am here: it neither keeps the rules awake nor wakes them', function()
    local s = settle(afk.new(0), 1, 100);
    for t = 101, afk.TIMEOUT - 1 do
        s = afk.update(s, { positions = moved(1, { x = 10 + t, y = 20, z = 30 }), combat = true }, t);
    end
    assert_eq(afk.asleep(s), false, 'one second short');
    s = afk.update(s, { positions = moved(1, { x = 999, y = 20, z = 30 }), combat = true }, afk.TIMEOUT);
    assert_eq(afk.asleep(s), true, 'the tank walking and the party fighting the whole time did not count');
    s = afk.update(s, { positions = STILL, combat = true }, afk.TIMEOUT + 1);
    assert_eq(afk.asleep(s), true, 'a claim does not wake it');
end);

test('asleep, my own movement or key press wakes it and restarts the full timeout', function()
    local s = settle(afk.new(0), 1, afk.TIMEOUT);
    assert_eq(afk.asleep(s), true);
    local here = moved(0, { x = 1.5, y = 2, z = 3 });
    local s2, change = afk.update(s, { positions = here, combat = false }, afk.TIMEOUT + 3);
    assert_eq(afk.asleep(s2), false);
    assert_eq(change, 'awake');
    s2 = settle(s2, afk.TIMEOUT + 4, 2 * afk.TIMEOUT + 2, here);
    assert_eq(afk.asleep(s2), false, 'waking restarts the full timeout');
    local s3, slept = afk.update(s2, { positions = here, combat = false }, 2 * afk.TIMEOUT + 3);
    assert_eq(afk.asleep(s3), true);
    assert_eq(slept, 'asleep');
    local s4, woke = afk.update(s3, { positions = here, combat = false, input = true }, 2 * afk.TIMEOUT + 4);
    assert_eq(afk.asleep(s4), false, 'a key press wakes it too');
    assert_eq(woke, 'awake');
end);

test('the first sample is not movement', function()
    local s = afk.new(0);
    s = afk.update(s, { positions = STILL, combat = false }, 50);
    assert_eq(s.still_since, 0, 'nothing to compare the first sample against');
end);

test('update does not mutate the state it was given', function()
    local s = afk.new(0);
    local s2 = afk.update(s, { positions = STILL, combat = false }, 1);
    assert_eq(s.positions[0], nil);
    assert_eq(s2.positions[0], STILL[0]);
end);
