local F   = dofile('tactician/tests/fixtures.lua');
local scope = require('lib.scope');

local function names(list)
    local out = {};
    for _, s in ipairs(list) do table.insert(out, s.name); end
    return out;
end

test('self is me, with my own readings and the <me> token', function()
    local list = scope.candidates('self', F.snapshot());
    assert_eq(names(list), { 'Me' });
    assert_eq(list[1].token, '<me>');
    assert_eq(list[1].hp_missing, 200);
    assert_eq(list[1].buffs, { [40] = true });
    assert_eq(list[1].kind, 'self');
end);

test('party is everyone alive including me, lowest HP first, with party slot tokens', function()
    local list = scope.candidates('party', F.snapshot());
    assert_eq(names(list), { 'Tank', 'Me', 'Arrow' });
    assert_eq(list[1].token, '<p1>');
    assert_eq(list[3].token, '<p3>');
    assert_eq(list[1].kind, 'member');
end);

test('roles filter the party by main job', function()
    local snap = F.snapshot();
    assert_eq(names(scope.candidates('tank', snap)), { 'Tank' });
    assert_eq(names(scope.candidates('ranged', snap)), { 'Arrow' });
    assert_eq(names(scope.candidates('caster', snap)), { 'Me' }, 'the dead black mage is skipped');
    assert_eq(names(scope.candidates('melee', snap)), { 'Tank' });
end);

test('party_dead is the members at zero HP', function()
    local list = scope.candidates('party_dead', F.snapshot());
    assert_eq(names(list), { 'Dead' });
    assert_eq(list[1].token, '<p2>');
    assert_eq(list[1].dead, true);
end);

test('target is the monster when there is one', function()
    local snap = F.snapshot();
    local list = scope.candidates('target', snap);
    assert_eq(names(list), { 'Goblin' });
    assert_eq(list[1].token, '<t>');
    assert_eq(list[1].kind, 'enemy');
    assert_eq(list[1].mpp, nil, 'a monster shows no MP');
    assert_eq(scope.candidates('target', F.snapshot({ target = false })), {});
end);

test('pet is the pet when there is one', function()
    assert_eq(scope.candidates('pet', F.snapshot()), {});
    local snap = F.snapshot({ pet = { id = 200, idx = 0x20, name = 'Carbuncle', hpp = 55, mpp = 80, tp = 900 } });
    local list = scope.candidates('pet', snap);
    assert_eq(names(list), { 'Carbuncle' });
    assert_eq(list[1].token, '<pet>');
    assert_eq(list[1].buffs, nil);
end);

test('a member without a status list still has readings', function()
    local list = scope.candidates('party', F.snapshot());
    assert_eq(list[3].buffs, nil);
    assert_eq(list[3].tp, 1500);
end);
