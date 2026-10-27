local tracker = require('lib.tracker');

local MOB = 500;

test('a cast start marks the actor as casting until it finishes or the window closes', function()
    local t = tracker.observe(tracker.new(), { actor = MOB, category = 8, param = 0 }, 10);
    assert_eq(tracker.flags(t, MOB, 11), { casting = true, readying = false });
    assert_eq(tracker.flags(t, MOB, 10 + tracker.CAST_WINDOW + 1), { casting = false, readying = false });
    t = tracker.observe(t, { actor = MOB, category = 4, param = 0 }, 12);
    assert_eq(tracker.flags(t, MOB, 12), { casting = false, readying = false });
end);

test('an interrupted cast clears casting', function()
    local t = tracker.observe(tracker.new(), { actor = MOB, category = 8, param = 0 }, 10);
    t = tracker.observe(t, { actor = MOB, category = 8, param = tracker.INTERRUPTED }, 11);
    assert_eq(tracker.flags(t, MOB, 11).casting, false);
end);

test('a readied TP move marks the actor until it lands', function()
    local t = tracker.observe(tracker.new(), { actor = MOB, category = 7, param = 0 }, 10);
    assert_eq(tracker.flags(t, MOB, 11).readying, true);
    assert_eq(tracker.flags(t, 999, 11).readying, false, 'another actor');
    t = tracker.observe(t, { actor = MOB, category = 11, param = 0 }, 12);
    assert_eq(tracker.flags(t, MOB, 12).readying, false);
end);

test('observe never changes the table it was given and prune drops the stale', function()
    local t0 = tracker.new();
    tracker.observe(t0, { actor = MOB, category = 8, param = 0 }, 10);
    assert_eq(t0, {});
    local t = tracker.observe(t0, { actor = MOB, category = 7, param = 0 }, 10);
    assert_eq(tracker.prune(t, 10 + tracker.READY_WINDOW + 1), {});
    assert_eq(tracker.prune(t, 11)[MOB] ~= nil, true);
end);

test('a weapon skill is remembered for WS_WINDOW seconds, and ws_age says how long ago it landed', function()
    local t = tracker.observe(tracker.new(), { actor = 101, category = 3, param = 0 }, 10);
    assert_eq(tracker.ws_age(t, 101, 12), 2);
    assert_eq(tracker.ws_age(t, 101, 10), 0, 'the tick it lands');
    assert_eq(tracker.ws_age(t, 999, 12), nil, 'another actor');
    assert_eq(tracker.ws_age(t, 101, 10 + tracker.WS_WINDOW - 1), tracker.WS_WINDOW - 1);
    assert_eq(tracker.ws_age(t, 101, 10 + tracker.WS_WINDOW), nil, 'forgotten once the window closes');
    assert_eq(tracker.ws_age(tracker.new(), 101, 12), nil);
    assert_eq(tracker.flags(t, 101, 11), { casting = false, readying = false }, 'a weapon skill is neither a cast nor a readied move');
end);

test('a weapon skill does not disturb what else the actor is doing, and prune keeps it until the window closes', function()
    local t = tracker.observe(tracker.new(), { actor = MOB, category = 8, param = 0 }, 10);
    t = tracker.observe(t, { actor = MOB, category = 3, param = 0 }, 11);
    assert_eq(tracker.flags(t, MOB, 12).casting, true);
    assert_eq(tracker.ws_age(t, MOB, 12), 1);
    t = tracker.observe(t, { actor = MOB, category = 4, param = 0 }, 13);
    assert_eq(tracker.ws_age(t, MOB, 14), 3, 'the cast finishing does not forget the weapon skill');
    assert_eq(tracker.prune(t, 11 + tracker.WS_WINDOW - 1)[MOB] ~= nil, true);
    assert_eq(tracker.prune(t, 11 + tracker.WS_WINDOW), {});
    local t0 = tracker.new();
    tracker.observe(t0, { actor = MOB, category = 3, param = 0 }, 10);
    assert_eq(t0, {}, 'observe never changes the table it was given');
end);

test('the tracker remembers a weapon skill at least as long as a rule may ask for', function()
    assert_eq(tracker.WS_WINDOW, 60);
    assert_eq(require('lib.vocab').condition('ws_within').max <= tracker.WS_WINDOW, true);
end);
