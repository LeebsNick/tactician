local document = require('lib.document');

-- every shipped template, as { job, doc }
local function templates()
    local out = {};
    local handle = io.popen('ls tactician/templates');
    for file in handle:lines() do
        local job = file:match('^(%u%u%u)%.txt$');
        if job then
            local lines = {};
            for line in io.lines('tactician/templates/' .. file) do table.insert(lines, line); end
            table.insert(out, { job = job, doc = document.parse(lines) });
        end
    end
    handle:close();
    return out;
end

local function rules(doc)
    local out = {};
    for _, r in ipairs(doc.rules) do
        if r.raw == nil then table.insert(out, r); end
    end
    return out;
end

test('every shipped template parses without an error line', function()
    local all = templates();
    assert_eq(#all >= 1, true, 'at least the SCH template ships');
    for _, t in ipairs(all) do
        for i, r in ipairs(t.doc.rules) do
            assert_eq(r.error, nil, ('%s line %d: %s'):format(t.job, i, tostring(r.error)));
        end
        assert_eq(#rules(t.doc) > 0, true, t.job .. ' has rules');
    end
end);

test('the Scholar template puts Light Arts up before any spell is cast', function()
    local sch;
    for _, t in ipairs(templates()) do if t.job == 'SCH' then sch = t.doc; end end
    local first = rules(sch)[1];
    assert_eq(first.scope, 'self');
    assert_eq(first.conds, { { key = 'not_status', arg = 'Light Arts' } });
    assert_eq(first.act, { reaction = 'ja', selector = 'specific', arg = 'Light Arts' });
    assert_eq(document.lines(sch)[5], 'party hpp_lt:50 ma:highest:Cure', 'cures come right after the arts');
end);
