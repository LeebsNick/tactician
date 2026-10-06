-- Minimal test runner shared by every addon, run from the repo root:
--   luajit tests/run.lua            every folder that has tests/*_test.lua
--   luajit tests/run.lua <addon>    one addon
-- Each addon's tests run with <addon>/ then the repo root on package.path, so require('lib.x')
-- finds the addon's own module first and the shared engine in lib/ otherwise.
local windows = package.config:sub(1, 1) == '\\';
local base_path = package.path;

local pass, fail = 0, 0;
local current;

local function dump(v)
    if type(v) ~= 'table' then return tostring(v); end
    local parts = {};
    for k, x in pairs(v) do table.insert(parts, tostring(k) .. '=' .. dump(x)); end
    table.sort(parts);
    return '{' .. table.concat(parts, ', ') .. '}';
end

local function deep_eq(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then return a == b; end
    for k, v in pairs(a) do if not deep_eq(v, b[k]) then return false; end end
    for k in pairs(b) do if a[k] == nil then return false; end end
    return true;
end

function assert_eq(actual, expected, msg)
    if not deep_eq(actual, expected) then
        error(('%s\n  expected: %s\n  actual:   %s'):format(msg or 'assert_eq', dump(expected), dump(actual)), 2);
    end
end

function test(name, fn)
    local ok, err = pcall(fn);
    if ok then pass = pass + 1;
    else fail = fail + 1; print(('FAIL %s :: %s\n  %s'):format(current, name, tostring(err))); end
end

local function list_dir(dir)
    local cmd = windows and ('dir /b "%s" 2>nul'):format(dir:gsub('/', '\\')) or ('ls "%s" 2>/dev/null'):format(dir);
    local handle, out = io.popen(cmd), {};
    for entry in handle:lines() do table.insert(out, entry); end
    handle:close();
    table.sort(out);
    return out;
end

local function list_tests(dir)
    local out = {};
    for _, file in ipairs(list_dir(dir)) do
        if file:match('_test%.lua$') then table.insert(out, file); end
    end
    return out;
end

local function run_addon(addon_dir, files)
    local tests_dir = addon_dir .. '/tests';
    local before_pass, before_fail = pass, fail;
    package.path = addon_dir .. '/?.lua;./?.lua;' .. base_path;
    -- Two addons may both have a lib/route.lua; drop the previous addon's cached modules.
    for name in pairs(package.loaded) do
        if name:match('^lib%.') then package.loaded[name] = nil; end
    end
    for _, file in ipairs(files) do
        current = file;
        local ok, err = pcall(dofile, tests_dir .. '/' .. file);
        if not ok then fail = fail + 1; print(('FAIL %s :: could not load\n  %s'):format(file, tostring(err))); end
    end
    print(('%s: %d passed, %d failed'):format(addon_dir, pass - before_pass, fail - before_fail));
end

local function addons_with_tests()
    local out = {};
    for _, entry in ipairs(list_dir('.')) do
        local files = list_tests(entry .. '/tests');
        if #files > 0 then table.insert(out, { dir = entry, files = files }); end
    end
    return out;
end

local addon_dir = arg[1];
if addon_dir ~= nil then
    addon_dir = addon_dir:gsub('[/\\]+$', '');
    local files = list_tests(addon_dir .. '/tests');
    if #files == 0 then
        io.stderr:write(('no *_test.lua files in %s/tests\n'):format(addon_dir));
        os.exit(2);
    end
    run_addon(addon_dir, files);
else
    local addons = addons_with_tests();
    if #addons == 0 then
        io.stderr:write('no <addon>/tests/*_test.lua files found; run from the repo root\n');
        os.exit(2);
    end
    for _, a in ipairs(addons) do run_addon(a.dir, a.files); end
    print(('total: %d passed, %d failed'):format(pass, fail));
end
os.exit(fail == 0 and 0 or 1);
