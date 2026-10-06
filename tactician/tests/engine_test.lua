local F        = dofile('tactician/tests/fixtures.lua');
local document = require('lib.document');
local engine   = require('lib.engine');

local cat = F.catalog();
local function never() return 0.99; end

local DOC = document.parse({
    'party_dead always ma:Raise',
    'party hpp_lt:50 ma:highest:Cure',
    'self not_status:Protect ma:highest:Protect',
    'target casting_ma ma:Stun',
    'self tp_gte:1000 ws:"Fast Blade" retry:3',
});

test('the first rule whose scope, if and then all resolve fires, with its command', function()
    local snap = F.snapshot();
    local fire = engine.pick(DOC, cat, snap, engine.new(), never);
    assert_eq(fire.index, 1, 'the dead black mage is raised before the tank is cured');
    assert_eq(fire.command, '/ma "Raise" <p2>');
    assert_eq(fire.subject.name, 'Dead');
end);

test('a rule whose action cannot fire right now is skipped for the next', function()
    local snap = F.snapshot();
    snap.recast.spell[12] = 20;
    local fire = engine.pick(DOC, cat, snap, engine.new(), never);
    assert_eq(fire.index, 2);
    assert_eq(fire.command, '/ma "Cure IV" <p1>');
end);

test('a rule stays quiet for its retry after firing, and a rule without retry does not', function()
    local snap = F.snapshot();
    snap.recast.spell[12] = 20;
    snap.party[1].hpp = 90;
    snap.me.buffs = {};
    local state = engine.new();
    local fire = engine.pick(DOC, cat, snap, state, never);
    assert_eq(fire.index, 3, 'Protect is missing');
    snap.me.buffs = { [40] = true };
    fire = engine.pick(DOC, cat, snap, state, never);
    assert_eq(fire.index, 5, 'TP is 1200');
    state = engine.fired(state, 5, snap.now);
    assert_eq(engine.pick(DOC, cat, snap, state, never), nil, 'within the 3 second retry');
    snap.now = snap.now + 3;
    assert_eq(engine.pick(DOC, cat, snap, state, never).index, 5);
end);

test('a refused rule backs off before it is tried again', function()
    local snap = F.snapshot();
    snap.recast.spell[12] = 20;
    local state = engine.refused(engine.new(), 2, snap.now);
    assert_eq(engine.pick(DOC, cat, snap, state, never).index, 5, 'the cure is backing off');
    snap.now = snap.now + engine.BACKOFF;
    assert_eq(engine.pick(DOC, cat, snap, state, never).index, 2);
end);

test('switched-off rules, comments and broken lines never fire', function()
    local doc = document.parse({ '# note', 'broken line', 'off party_dead always ma:Raise', 'party hpp_lt:50 ma:highest:Cure' });
    local fire = engine.pick(doc, cat, F.snapshot(), engine.new(), never);
    assert_eq(fire.index, 4);
end);

test('nothing fires when nothing applies', function()
    local snap = F.snapshot();
    snap.party = {};
    snap.me.tp = 0;
    assert_eq(engine.pick(DOC, cat, snap, engine.new(), never), nil);
end);

test('a target rule fires only on what the target is doing', function()
    local snap = F.snapshot();
    snap.party = {};
    snap.me.tp = 0;
    snap.known.spell[252] = true;
    snap.me.job, snap.me.level = 8, 41;
    snap.target.casting = true;
    local fire = engine.pick(DOC, cat, snap, engine.new(), never);
    assert_eq(fire.command, '/ma "Stun" <t>');
end);

test('inert says why a rule can never fire as written, and nothing for one that merely waits', function()
    local snap = F.snapshot();
    assert_eq(engine.inert(document.parse({ 'self always ma:Nothing' }).rules[1], cat, snap), 'unknown spell');
    assert_eq(engine.inert(document.parse({ 'target always ma:Stun' }).rules[1], cat, snap), 'not learned');
    assert_eq(engine.inert(document.parse({ 'self always ma:Raise' }).rules[1], cat, snap), 'cannot target me');
    assert_eq(engine.inert(document.parse({ 'party hpp_lt:50 ma:highest:Cure' }).rules[1], cat, snap), nil);
    snap.target = nil;
    assert_eq(engine.inert(document.parse({ 'target casting_ma ma:Dia' }).rules[1], cat, snap), nil, 'no target is a wait, not a fault');
    snap.recast.spell[23] = 4;
    assert_eq(engine.inert(document.parse({ 'target casting_ma ma:Dia' }).rules[1], cat, snap), nil);
end);

test('not being engaged is a wait, not a fault, so the editor does not mark the rule', function()
    local snap = F.snapshot();
    snap.me.status = 'idle';
    assert_eq(engine.inert(document.parse({ 'self tp_gte:1000 ws:"Fast Blade"' }).rules[1], cat, snap), nil);
    assert_eq(engine.pick(document.parse({ 'self tp_gte:1000 ws:"Fast Blade"' }), cat, snap, engine.new()), nil);
end);
