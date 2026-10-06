local pacing = require('lib.pacing');

local SPELL = { kind = 'ma', name = 'Cure III', cast = 2.5 };
local JA    = { kind = 'ja', name = 'Provoke' };

test('a fresh pacer is ready and a sent action makes it wait', function()
    local p = pacing.new();
    assert_eq(pacing.ready(p), true);
    p = pacing.send(p, SPELL, 10);
    assert_eq(pacing.ready(p), false);
    assert_eq(p.action, SPELL);
end);

test('a spell that starts stays busy for its cast time and frees on finish', function()
    local p = pacing.send(pacing.new(), SPELL, 10);
    p = pacing.event(p, { kind = 'start' }, 10.4);
    assert_eq(p.phase, 'busy');
    local p2, outcome = pacing.step(p, 12);
    assert_eq(outcome, nil);
    assert_eq(pacing.ready(p2), false, 'still casting at 12');
    p2 = pacing.event(p2, { kind = 'finish' }, 13);
    assert_eq(pacing.ready(p2), true);
end);

test('an interrupted cast frees the pacer at once and says so', function()
    local p = pacing.send(pacing.new(), SPELL, 10);
    p = pacing.event(p, { kind = 'start' }, 10.4);
    local p2, outcome = pacing.event(p, { kind = 'interrupt' }, 11);
    assert_eq(outcome, 'interrupted');
    assert_eq(pacing.ready(p2), true);
end);

test('an action the game never started is reported refused after a short wait', function()
    local p = pacing.send(pacing.new(), JA, 10);
    local p2, outcome = pacing.step(p, 11);
    assert_eq(outcome, nil);
    assert_eq(pacing.ready(p2), false);
    local p3, outcome3 = pacing.step(p2, 10 + pacing.START_TIMEOUT);
    assert_eq(outcome3, 'refused');
    assert_eq(pacing.ready(p3), true);
end);

test('an instant action frees on its finish packet', function()
    local p = pacing.send(pacing.new(), JA, 10);
    p = pacing.event(p, { kind = 'finish' }, 10.3);
    assert_eq(pacing.ready(p), true);
end);

test('a cast whose finish never arrives frees after the cast time plus grace', function()
    local p = pacing.send(pacing.new(), SPELL, 10);
    p = pacing.event(p, { kind = 'start' }, 10.5);
    local _, early = pacing.step(p, 10.5 + 2.5 + pacing.GRACE - 0.1);
    assert_eq(early, nil);
    local p2, late = pacing.step(p, 10.5 + 2.5 + pacing.GRACE + 0.1);
    assert_eq(late, 'timeout');
    assert_eq(pacing.ready(p2), true);
end);

test('events while idle change nothing', function()
    local p = pacing.new();
    assert_eq(pacing.event(p, { kind = 'finish' }, 5), p);
    assert_eq(pacing.event(p, { kind = 'start' }, 5), p);
end);
