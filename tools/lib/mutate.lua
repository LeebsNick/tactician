-- Pure half of the manual mutation pass: parses tools/mutants.txt, applies one mutant, judges the outcome.
local M = {};

local EXPECT = { killed = true, equivalent = true };

function M.parse(text)
    local out = {};
    local n = 0;
    for line in (text .. '\n'):gmatch('([^\n]*)\n') do
        n = n + 1;
        if line ~= '' and line:sub(1, 1) ~= '#' then
            local file, find, replace, expect, note = line:match('^([^\t]+)\t([^\t]+)\t([^\t]*)\t([^\t]+)\t?(.*)$');
            if file == nil then error(('mutants line %d: expected file<TAB>find<TAB>replace<TAB>expect[<TAB>note]'):format(n)); end
            if not EXPECT[expect] then error(('mutants line %d: expect must be killed or equivalent, got %q'):format(n, expect)); end
            table.insert(out, { file = file, find = find, replace = replace, expect = expect, note = note });
        end
    end
    return out;
end

function M.apply(source, find, replace)
    local at = source:find(find, 1, true);
    if at == nil then return nil; end
    return source:sub(1, at - 1) .. replace .. source:sub(at + #find);
end

-- Which tests to run for a module: its addon's, or every addon's for the shared lib/, since
-- the window test that exercises lib/view.lua lives with the artifact chains.
function M.addon_of(path)
    local top = path:match('^([^/\\]+)');
    return top == 'lib' and '' or top;
end

-- survived: true if the tests still passed, false if they failed, nil if the mutant could not be applied.
function M.verdict(mutant, survived)
    if survived == nil then return { ok = false, label = 'NOT FOUND (stale)' }; end
    if mutant.expect == 'killed' then
        return survived and { ok = false, label = 'SURVIVED' } or { ok = true, label = 'killed' };
    end
    return survived and { ok = true, label = 'survived (accepted)' }
        or { ok = true, label = 'killed (was accepted; drop it from the list)' };
end

function M.summary(verdicts)
    local failed = 0;
    for _, v in ipairs(verdicts) do if not v.ok then failed = failed + 1; end end
    return { total = #verdicts, failed = failed, ok = failed == 0 };
end

return M;
