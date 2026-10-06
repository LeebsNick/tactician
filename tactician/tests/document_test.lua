local document = require('lib.document');
local rule     = require('lib.rule');

local LINES = {
    '# cures first',
    'party hpp_lt:50 ma:"Cure III"',
    'self not_status:Protect ma:highest:Protect',
    'this line is broken',
    'off target casting_ma ja:Stun',
};

test('a file parses into rules, keeps comments and broken lines, and writes back unchanged', function()
    local doc = document.parse(LINES);
    assert_eq(#doc.rules, 5);
    assert_eq(doc.rules[1].raw, '# cures first');
    assert_eq(doc.rules[1].error, nil);
    assert_eq(doc.rules[2].scope, 'party');
    assert_eq(doc.rules[4].raw, 'this line is broken');
    assert_eq(type(doc.rules[4].error), 'string');
    assert_eq(doc.rules[5].enabled, false);
    assert_eq(document.lines(doc), LINES);
end);

test('blank lines are dropped', function()
    assert_eq(document.lines(document.parse({ '', 'self always ja:Provoke', '   ' })), { 'self always ja:Provoke' });
end);

test('add, remove, move, toggle, duplicate and set return new documents', function()
    local doc = document.parse({ 'self always ja:Provoke', 'party hpp_lt:50 ma:"Cure III"' });
    local added = document.add(doc, rule.parse('target always rattack'));
    assert_eq(#added.rules, 3);
    assert_eq(#doc.rules, 2, 'the original is untouched');

    local removed = document.remove(added, 1);
    assert_eq(document.lines(removed), { 'party hpp_lt:50 ma:"Cure III"', 'target always rattack' });

    local moved = document.move(added, 3, 1);
    assert_eq(document.lines(moved), { 'target always rattack', 'self always ja:Provoke', 'party hpp_lt:50 ma:"Cure III"' });
    assert_eq(document.lines(document.move(added, 1, 3))[3], 'self always ja:Provoke');

    local toggled = document.toggle(doc, 1);
    assert_eq(toggled.rules[1].enabled, false);
    assert_eq(doc.rules[1].enabled, true);
    assert_eq(document.toggle(toggled, 1).rules[1].enabled, true);

    local dup = document.duplicate(doc, 1);
    assert_eq(document.lines(dup), { 'self always ja:Provoke', 'self always ja:Provoke', 'party hpp_lt:50 ma:"Cure III"' });

    local set = document.set(doc, 2, rule.parse('party hpp_lt:75 ma:"Cure II"'));
    assert_eq(document.lines(set)[2], 'party hpp_lt:75 ma:"Cure II"');
    assert_eq(document.lines(doc)[2], 'party hpp_lt:50 ma:"Cure III"');
end);

test('a move out of range or onto itself changes nothing', function()
    local doc = document.parse({ 'self always ja:Provoke', 'target always rattack' });
    assert_eq(document.move(doc, 1, 1), doc);
    assert_eq(document.move(doc, 0, 1), doc);
    assert_eq(document.move(doc, 1, 3), doc);
end);

test('toggling or duplicating a raw line leaves it alone', function()
    local doc = document.parse({ '# note' });
    assert_eq(document.toggle(doc, 1), doc);
    assert_eq(document.duplicate(doc, 1), doc);
end);

test('two documents with the same lines are equal, which is how dirty is decided', function()
    local a = document.parse(LINES);
    local b = document.parse(document.lines(a));
    assert_eq(document.same(a, b), true);
    assert_eq(document.same(a, document.toggle(a, 2)), false);
end);
