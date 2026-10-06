local mutate = require('lib.mutate');

test('parse reads tab-separated mutants and skips comments and blank lines', function()
    local list = mutate.parse(table.concat({
        '# file\tfind\treplace\texpect\tnote',
        '',
        'a/lib/x.lua\t< 40\t<= 40\tequivalent\tonly differs at exactly 40',
        'a/lib/x.lua\t+ 1\t- 1\tkilled',
    }, '\n'));
    assert_eq(list, {
        { file = 'a/lib/x.lua', find = '< 40', replace = '<= 40', expect = 'equivalent', note = 'only differs at exactly 40' },
        { file = 'a/lib/x.lua', find = '+ 1', replace = '- 1', expect = 'killed', note = '' },
    });
end);

test('parse rejects an unknown expectation with the line number', function()
    local ok, err = pcall(mutate.parse, 'a.lua\tx\ty\tmaybe');
    assert_eq(ok, false);
    assert_eq(err:find('line 1', 1, true) ~= nil, true, err);
end);

test('apply replaces the first occurrence only, as plain text', function()
    assert_eq(mutate.apply('if d < 40 and e < 40 then', '< 40', '<= 40'), 'if d <= 40 and e < 40 then');
    assert_eq(mutate.apply('a.b', '.', '-'), 'a-b', 'no pattern magic');
end);

test('apply returns nil when the text to mutate is not in the source', function()
    assert_eq(mutate.apply('x = 1', 'y', 'z'), nil);
end);

test('addon_of gives the top-level folder of a module path', function()
    assert_eq(mutate.addon_of('storagehole/lib/route.lua'), 'storagehole');
    assert_eq(mutate.addon_of('lib/view.lua'), '', 'the shared engine runs every addon\'s tests');
end);

test('verdict: a mutant expected killed must fail the tests', function()
    assert_eq(mutate.verdict({ expect = 'killed' }, false), { ok = true, label = 'killed' });
    assert_eq(mutate.verdict({ expect = 'killed' }, true), { ok = false, label = 'SURVIVED' });
end);

test('verdict: an accepted equivalent mutant is fine either way but says when it now dies', function()
    assert_eq(mutate.verdict({ expect = 'equivalent' }, true), { ok = true, label = 'survived (accepted)' });
    assert_eq(mutate.verdict({ expect = 'equivalent' }, false), { ok = true, label = 'killed (was accepted; drop it from the list)' });
end);

test('verdict: a mutant whose text is missing is a stale entry', function()
    assert_eq(mutate.verdict({ expect = 'killed' }, nil), { ok = false, label = 'NOT FOUND (stale)' });
end);

test('summary counts and reports failures', function()
    local s = mutate.summary({ { ok = true }, { ok = false }, { ok = true } });
    assert_eq(s, { total = 3, failed = 1, ok = false });
    assert_eq(mutate.summary({ { ok = true } }), { total = 1, failed = 0, ok = true });
end);
