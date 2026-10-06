local F       = dofile('tactician/tests/fixtures.lua');
local actions = require('lib.actions');
local scope     = require('lib.scope');

local cat = F.catalog();

local function me(snap) return scope.candidates('self', snap)[1]; end
local function member(snap, n) return scope.candidates('party', snap)[n]; end
local function target(snap) return scope.candidates('target', snap)[1]; end

test('a known, affordable, ready spell resolves with its cast time and the subject token', function()
    local snap = F.snapshot();
    local a = actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Cure III' }, member(snap, 1), cat, snap);
    assert_eq(a, { kind = 'ma', id = 3, name = 'Cure III', token = '<p1>', cast = 2.5 });
end);

test('the best tier of a family is the highest one that is learned, usable at level, affordable and off recast', function()
    local snap = F.snapshot();
    local best = actions.resolve({ reaction = 'ma', selector = 'highest', arg = 'Cure' }, me(snap), cat, snap);
    assert_eq(best.id, 4, 'Cure IV at WHM41 with 300 MP');
    snap.me.mp = 50;
    assert_eq(actions.resolve({ reaction = 'ma', selector = 'highest', arg = 'Cure' }, me(snap), cat, snap).id, 3);
    snap.recast.spell[3] = 12;
    assert_eq(actions.resolve({ reaction = 'ma', selector = 'highest', arg = 'Cure' }, me(snap), cat, snap).id, 2);
    snap.me.level = 10;
    assert_eq(actions.resolve({ reaction = 'ma', selector = 'highest', arg = 'Cure' }, me(snap), cat, snap).id, 1);
end);

test('a sub job can supply the spell', function()
    local snap = F.snapshot();
    snap.known.spell[144] = true;
    local fire = actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Fire' }, target(snap), cat, snap);
    assert_eq(fire.id, 144, 'Fire is BLM13 and the sub is BLM20');
    local _, why = actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Fire II' }, target(snap), cat, snap);
    assert_eq(why, 'not learned');
    snap.known.spell[145] = true;
    _, why = actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Fire II' }, target(snap), cat, snap);
    assert_eq(why, 'needs BLM 38');
end);

test('each refusal names its reason', function()
    local snap = F.snapshot();
    local cases = {
        { { reaction = 'ma', selector = 'specific', arg = 'Nothing' }, me(snap), 'unknown spell' },
        { { reaction = 'ma', selector = 'specific', arg = 'Stun' }, target(snap), 'not learned' },
        { { reaction = 'ma', selector = 'highest', arg = 'Nothing' }, me(snap), 'unknown family' },
        { { reaction = 'ja', selector = 'specific', arg = 'Provoke' }, target(snap), 'not learned' },
        { { reaction = 'ws', selector = 'specific', arg = 'Combo' }, target(snap), 'not learned' },
        { { reaction = 'item', selector = 'specific', arg = 'Potion' }, me(snap), 'unknown item' },
    };
    for _, case in ipairs(cases) do
        local a, why = actions.resolve(case[1], case[2], cat, snap);
        assert_eq(a, nil, case[3]);
        assert_eq(why, case[3]);
    end
    snap.me.mp = 10;
    local _, why = actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Cure III' }, me(snap), cat, snap);
    assert_eq(why, 'not enough MP');
    snap.me.mp = 300;
    snap.recast.spell[3] = 5;
    _, why = actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Cure III' }, me(snap), cat, snap);
    assert_eq(why, 'recast 5s');
end);

test('a spell that cannot land on its scope but can land on the target goes to the target', function()
    local snap = F.snapshot();
    local dia = actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Dia' }, me(snap), cat, snap);
    assert_eq(dia.token, '<t>');
    snap.target = nil;
    local a, why = actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Dia' }, me(snap), cat, snap);
    assert_eq(a, nil);
    assert_eq(why, 'no target');
end);

test('a cure cannot land on a dead member and a raise only can', function()
    local snap = F.snapshot();
    local dead = scope.candidates('party_dead', snap)[1];
    local _, why = actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Cure' }, dead, cat, snap);
    assert_eq(why, 'cannot target dead party member');
    assert_eq(actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Raise' }, dead, cat, snap).token, '<p2>');
    _, why = actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Raise' }, me(snap), cat, snap);
    assert_eq(why, 'cannot target me');
end);

test('a self-only spell lands on me whatever the scope was', function()
    local snap = F.snapshot();
    local a = actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Protectra' }, member(snap, 1), cat, snap);
    assert_eq(a.token, '<me>');
end);

test('abilities check learned, recast and TP', function()
    local snap = F.snapshot();
    local seal = actions.resolve({ reaction = 'ja', selector = 'specific', arg = 'Divine Seal' }, me(snap), cat, snap);
    assert_eq(seal, { kind = 'ja', id = 528, name = 'Divine Seal', token = '<me>' });
    snap.recast.ability[13] = 30;
    local _, why = actions.resolve({ reaction = 'ja', selector = 'specific', arg = 'Divine Seal' }, me(snap), cat, snap);
    assert_eq(why, 'recast 30s');
    snap.known.ability[608] = true;
    snap.known.ability[609] = true;
    snap.me.tp = 300;
    local waltz = actions.resolve({ reaction = 'ja', selector = 'highest', arg = 'Curing Waltz' }, member(snap, 1), cat, snap);
    assert_eq(waltz.id, 608, 'Curing Waltz II wants 350 TP');
    snap.me.tp = 100;
    _, why = actions.resolve({ reaction = 'ja', selector = 'highest', arg = 'Curing Waltz' }, member(snap, 1), cat, snap);
    assert_eq(why, 'not enough TP');
end);

test('a weapon skill needs 1000 TP and a target, and always lands on the target', function()
    local snap = F.snapshot();
    local ws = actions.resolve({ reaction = 'ws', selector = 'specific', arg = 'Fast Blade' }, me(snap), cat, snap);
    assert_eq(ws, { kind = 'ws', id = 32, name = 'Fast Blade', token = '<t>' });
    snap.me.tp = 999;
    local _, why = actions.resolve({ reaction = 'ws', selector = 'specific', arg = 'Fast Blade' }, me(snap), cat, snap);
    assert_eq(why, 'not enough TP');
    snap.me.tp = 1000;
    snap.target = nil;
    _, why = actions.resolve({ reaction = 'ws', selector = 'specific', arg = 'Fast Blade' }, me(snap), cat, snap);
    assert_eq(why, 'no target');
end);

test('a ranged attack needs only a target', function()
    local snap = F.snapshot();
    assert_eq(actions.resolve({ reaction = 'rattack' }, me(snap), cat, snap), { kind = 'rattack', token = '<t>' });
    snap.target = nil;
    local _, why = actions.resolve({ reaction = 'rattack' }, me(snap), cat, snap);
    assert_eq(why, 'no target');
end);

test('an item needs to be in the bags and is used on me', function()
    local snap = F.snapshot();
    local a = actions.resolve({ reaction = 'item', selector = 'specific', arg = 'Hi-Potion' }, member(snap, 1), cat, snap);
    assert_eq(a, { kind = 'item', id = 4116, name = 'Hi-Potion', token = '<me>' });
    snap.items[4116] = 0;
    local _, why = actions.resolve({ reaction = 'item', selector = 'specific', arg = 'Hi-Potion' }, me(snap), cat, snap);
    assert_eq(why, 'none in bags');
end);

test('nothing aimed at the monster fires unless I am engaged; cures and self buffs still do', function()
    local snap = F.snapshot();
    snap.me.status = 'idle';
    snap.known.spell[23] = true;
    local cases = {
        { reaction = 'ws', selector = 'specific', arg = 'Fast Blade' },
        { reaction = 'rattack', selector = 'none' },
        { reaction = 'ma', selector = 'specific', arg = 'Dia' },
    };
    for _, act in ipairs(cases) do
        local a, why = actions.resolve(act, target(snap), cat, snap);
        assert_eq(a, nil, act.reaction .. ' while idle');
        assert_eq(why, 'not engaged');
    end
    local _, why = actions.resolve({ reaction = 'ws', selector = 'specific', arg = 'Fast Blade' }, me(snap), cat, snap);
    assert_eq(why, 'not engaged', 'the self-scope weapon skill idiom lands on <t> and is gated the same way');
    assert_eq(actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Cure III' }, member(snap, 1), cat, snap).token, '<p1>');
    assert_eq(actions.resolve({ reaction = 'ma', selector = 'specific', arg = 'Protect' }, me(snap), cat, snap).token, '<me>');
    snap.me.status = 'engaged';
    assert_eq(actions.resolve({ reaction = 'ws', selector = 'specific', arg = 'Fast Blade' }, target(snap), cat, snap).token, '<t>');
end);
