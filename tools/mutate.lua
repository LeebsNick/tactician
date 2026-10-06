-- Manual mutation pass, made repeatable. From the repo root:
--   luajit tools/mutate.lua [<addon>/lib/<module>.lua]
-- Applies each mutant in tools/mutants.txt to a copy of the module, runs that addon's tests,
-- restores the file, and checks the outcome against the recorded expectation.
package.path = 'tools/?.lua;' .. package.path;
local mutate = require('lib.mutate');

local only = arg[1];

local function read(path)
    local f = assert(io.open(path, 'r'));
    local text = f:read('*a');
    f:close();
    return text;
end

local function write(path, text)
    local f = assert(io.open(path, 'w'));
    f:write(text);
    f:close();
end

local function tests_pass(addon)
    local null = package.config:sub(1, 1) == '\\' and 'nul' or '/dev/null';
    local ok = os.execute(('luajit tests/run.lua %s > %s 2>&1'):format(addon, null));
    return ok == 0 or ok == true;
end

local verdicts = {};
for _, m in ipairs(mutate.parse(read('tools/mutants.txt'))) do
    if only == nil or m.file == only then
        local original = read(m.file);
        local mutated = mutate.apply(original, m.find, m.replace);
        local survived = nil;
        if mutated then
            write(m.file, mutated);
            local ok, result = pcall(tests_pass, mutate.addon_of(m.file));
            write(m.file, original);
            if not ok then error(result); end
            survived = result;
        end
        local v = mutate.verdict(m, survived);
        table.insert(verdicts, v);
        print(('%-8s %-42s %s -> %s  %s'):format(v.ok and 'ok' or 'FAIL', m.file, m.find, m.replace, v.label));
    end
end

local s = mutate.summary(verdicts);
print(('%d mutants, %d problems'):format(s.total, s.failed));
os.exit(s.ok and 0 or 1);
