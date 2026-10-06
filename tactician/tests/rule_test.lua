local rule = require('lib.rule');

local function cure()
    return { enabled = true, scope = 'party', conds = { { key = 'hpp_lt', arg = 50 } },
             act = { reaction = 'ma', selector = 'specific', arg = 'Cure III' }, retry = 0 };
end

test('a typed line parses into a rule and serialises back to the same line', function()
    local line = 'party hpp_lt:50 ma:"Cure III"';
    local r, err = rule.parse(line);
    assert_eq(err, nil);
    assert_eq(r, cure());
    assert_eq(rule.line(r), line);
end);

test('a second condition joins with and or or', function()
    local r = rule.parse('party hpp_lt:50 and not_status:Weakness ma:"Cure III"');
    assert_eq(r.conds, { { key = 'hpp_lt', arg = 50 }, { key = 'not_status', arg = 'Weakness' } });
    assert_eq(r.logic, 'and');
    assert_eq(rule.line(r), 'party hpp_lt:50 and not_status:Weakness ma:"Cure III"');
    assert_eq(rule.parse('self hpp_lt:30 or mpp_lt:10 ja:Convert').logic, 'or');
end);

test('a family selector, an off switch and a retry survive the round trip', function()
    local line = 'off self not_status:Protect ma:highest:Protect retry:5';
    local r = rule.parse(line);
    assert_eq(r.enabled, false);
    assert_eq(r.act, { reaction = 'ma', selector = 'highest', arg = 'Protect' });
    assert_eq(r.retry, 5);
    assert_eq(rule.line(r), line);
end);

test('an argument-free action and condition need no colon', function()
    local r = rule.parse('target casting_ma ja:Stun');
    assert_eq(r.conds, { { key = 'casting_ma' } });
    local ra = rule.parse('target always rattack');
    assert_eq(ra.act, { reaction = 'rattack' });
    assert_eq(rule.line(ra), 'target always rattack');
end);

test('names with spaces or colons are quoted, plain names are not', function()
    local r = rule.parse('self always ma:"Utsusemi: Ichi"');
    assert_eq(r.act.arg, 'Utsusemi: Ichi');
    assert_eq(rule.line(r), 'self always ma:"Utsusemi: Ichi"');
    assert_eq(rule.line(rule.parse('self tp_gte:1000 ws:"Fast Blade"')), 'self tp_gte:1000 ws:"Fast Blade"');
    assert_eq(rule.line(rule.parse('self always item:Hi-Potion')), 'self always item:Hi-Potion');
end);

test('a malformed line says what is wrong', function()
    local cases = {
        { '', 'scope' },
        { 'nobody always ja:Stun', 'scope' },
        { 'self sometimes ja:Stun', 'condition' },
        { 'self hpp_lt ja:Stun', 'hpp_lt needs a number' },
        { 'self hpp_lt:200 ja:Stun', '1 to 100' },
        { 'self status ja:Stun', 'status needs a name' },
        { 'self always', 'action' },
        { 'self always dance:Jig', 'action' },
        { 'self always ws:highest:Fast', 'highest' },
        { 'self always ma:', 'name' },
        { 'self always rattack:now', 'rattack takes no' },
        { 'self hpp_lt:50 and ja:Stun', 'second condition' },
        { 'self always ja:Stun retry:soon', 'retry' },
        { 'self always ja:Stun extra', 'extra' },
    };
    for _, case in ipairs(cases) do
        local r, err = rule.parse(case[1]);
        assert_eq(r, nil, case[1]);
        assert_eq(type(err) == 'string' and err:find(case[2], 1, true) ~= nil, true, case[1] .. ' -> ' .. tostring(err));
    end
end);

test('a condition that cannot be read for its scope is refused', function()
    local _, err = rule.parse('target mpp_lt:50 ma:Dia');
    assert_eq(err:find('mpp_lt', 1, true) ~= nil, true, err);
    local _, err2 = rule.parse('self casting_ma ja:Stun');
    assert_eq(err2:find('casting_ma', 1, true) ~= nil, true, err2);
end);

test('a weapon skill reads its scope but lands on the target, so any scope may carry one', function()
    assert_eq(rule.parse('self tp_gte:1000 ws:"Fast Blade"') ~= nil, true, 'my TP, my target');
    assert_eq(rule.parse('target hpp_lt:20 ws:"Fast Blade"') ~= nil, true, 'the target\'s HP');
    assert_eq(rule.parse('party always rattack') ~= nil, true);
end);

test('check reports the same problems on a rule built by hand', function()
    assert_eq(rule.check(cure()), nil);
    local bad = cure();
    bad.scope = 'target';
    bad.conds = { { key = 'mpp_lt', arg = 50 } };
    assert_eq(rule.check(bad) ~= nil, true);
    local two = cure();
    two.conds = { { key = 'hpp_lt', arg = 50 }, { key = 'always' } };
    assert_eq(rule.check(two) ~= nil, true, 'two conditions need a logic word');
end);

test('a blank rule is a valid starting point', function()
    assert_eq(rule.check(rule.blank()) ~= nil, true, 'a blank rule has no action name yet');
    assert_eq(rule.blank().scope, 'self');
    assert_eq(rule.blank().enabled, true);
end);
