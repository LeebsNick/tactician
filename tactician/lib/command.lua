-- The slash command for a resolved action: exactly what a player would type.
local M = {};

local PREFIX = { ma = '/ma', ja = '/ja', ws = '/ws', item = '/item' };

function M.text(action)
    if action.kind == 'rattack' then return '/ra ' .. action.token; end
    return ('%s "%s" %s'):format(PREFIX[action.kind], action.name, action.token);
end

return M;
