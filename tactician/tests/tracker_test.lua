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
