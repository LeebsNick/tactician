-- Luacheck config for an Ashita v4 addon. In-game Lua is LuaJIT (Lua 5.1 + bit, ffi, etc.),
-- and the test runner uses plain luajit, so 'luajit' is the right std everywhere.
std = 'luajit'

max_line_length = 160

-- make stage leaves an unzipped copy of the addon under dist/stage/.
exclude_files = { 'dist/' }

-- Ashita v4 API available inside the game client.
read_globals = {
    'AshitaCore',
    'GetEntity',
    'GetPlayerEntity',
    ashita = {
        fields = {
            events = { fields = { 'register', 'unregister' } },
            fs = { fields = { 'create_dir', 'exists', 'get_dir' } },
            memory = { fields = { 'read_uint8', 'read_uint32' } },
        },
    },
}

-- Ashita creates the addon table before loading; the addon fills in its fields.
globals = { 'addon' }

-- Ashita's imgui binding injects the ImGui enums (ImGuiCond_*, ImGuiWindowFlags_*, ...)
-- as globals; allow reading any of them.
ignore = { '113/ImGui[%w_]+' }

files['tests/run.lua'] = {
    -- The runner defines the assertion helpers the *_test.lua files use.
    allow_defined_top = true,
}

files['*/tests/*_test.lua'] = {
    read_globals = { 'test', 'assert_eq' },
}
