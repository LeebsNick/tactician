local F          = dofile('tactician/tests/fixtures.lua');
local conditions = require('lib.conditions');
local scope        = require('lib.scope');

local cat = F.catalog();

local function env(over)
    local e = { now = 1000, random = function() return 0.5; end, status = function(name) return require('lib.catalog').status(cat, name); end };
    for k, v in pairs(over or {}) do e[k] = v; end
    return e;
end

local function me(snap) return scope.candidates('self', snap or F.snapshot())[1]; end
local function target(snap) return scope.candidates('target', snap or F.snapshot())[1]; end

test('always holds', function()
    assert_eq(conditions.holds({ key = 'always' }, me(), env()), true);
end);

test('HP, MP and TP thresholds compare against the subject', function()
    assert_eq(conditions.holds({ key = 'hpp_lt', arg = 81 }, me(), env()), true);
    assert_eq(conditions.holds({ key = 'hpp_lt', arg = 80 }, me(), env()), false);
    assert_eq(conditions.holds({ key = 'hpp_gte', arg = 80 }, me(), env()), true);
    assert_eq(conditions.holds({ key = 'mpp_lt', arg = 61 }, me(), env()), true);
    assert_eq(conditions.holds({ key = 'tp_gte', arg = 1000 }, me(), env()), true);
    assert_eq(conditions.holds({ key = 'tp_lt', arg = 1000 }, me(), env()), false);
    assert_eq(conditions.holds({ key = 'hp_missing', arg = 200 }, me(), env()), true);
    assert_eq(conditions.holds({ key = 'hp_missing', arg = 201 }, me(), env()), false);
end);

test('a reading the subject does not have never holds', function()
    assert_eq(conditions.holds({ key = 'mpp_lt', arg = 99 }, target(), env()), false);
    assert_eq(conditions.holds({ key = 'hp_missing', arg = 1 }, target(), env()), false);
end);

test('status and not_status read the subject by status name', function()
    assert_eq(conditions.holds({ key = 'status', arg = 'Protect' }, me(), env()), true);
    assert_eq(conditions.holds({ key = 'not_status', arg = 'Protect' }, me(), env()), false);
    assert_eq(conditions.holds({ key = 'not_status', arg = 'Weakness' }, me(), env()), true);
    assert_eq(conditions.holds({ key = 'status', arg = 'No Such Thing' }, me(), env()), false);
    assert_eq(conditions.holds({ key = 'not_status', arg = 'No Such Thing' }, me(), env()), false, 'an unknown name is not a missing effect');
end);

test('a subject whose statuses are not visible never passes a status test', function()
    local arrow = scope.candidates('party', F.snapshot())[3];
    assert_eq(arrow.name, 'Arrow');
    assert_eq(conditions.holds({ key = 'not_status', arg = 'Protect' }, arrow, env()), false);
    assert_eq(conditions.holds({ key = 'status', arg = 'Protect' }, arrow, env()), false);
end);

test('casting and readying come off the target', function()
    local snap = F.snapshot();
    snap.target.casting = true;
    assert_eq(conditions.holds({ key = 'casting_ma' }, target(snap), env()), true);
    assert_eq(conditions.holds({ key = 'readying_ms' }, target(snap), env()), false);
    assert_eq(conditions.holds({ key = 'casting_ma' }, me(), env()), false);
end);

test('random rolls against the chance', function()
    assert_eq(conditions.holds({ key = 'random', arg = 51 }, me(), env({ random = function() return 0.5; end })), true);
    assert_eq(conditions.holds({ key = 'random', arg = 50 }, me(), env({ random = function() return 0.5; end })), false);
end);

test('two conditions combine with and or or', function()
    local both = { conds = { { key = 'hpp_lt', arg = 90 }, { key = 'status', arg = 'Protect' } }, logic = 'and' };
    assert_eq(conditions.all(both, me(), env()), true);
    both.conds[2].arg = 'Weakness';
    assert_eq(conditions.all(both, me(), env()), false);
    both.logic = 'or';
    assert_eq(conditions.all(both, me(), env()), true);
    assert_eq(conditions.all({ conds = { { key = 'always' } } }, me(), env()), true);
end);
