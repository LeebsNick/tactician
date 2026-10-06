-- Spell families and tiers from names alone, so no spell table has to ship: 'Cure III' is
-- tier 3 of cure, 'Utsusemi: Ni' is tier 2 of utsusemi, 'Haste' is tier 1 of haste.
local M = {};

M.ROMAN = { i = 1, ii = 2, iii = 3, iv = 4, v = 5, vi = 6, ichi = 1, ni = 2, san = 3 };

-- family key (lowercase, numeral and trailing colon removed) and tier number
function M.split(name)
    local lower = name:lower();
    local base, suffix = lower:match('^(.-)[%s:]+(%a+)$');
    if base ~= nil and M.ROMAN[suffix] ~= nil then
        return (base:gsub('[%s:]+$', '')), M.ROMAN[suffix];
    end
    return lower, 1;
end

-- the name as shown for the family: the spell's own spelling minus its numeral
function M.display(name)
    local _, tier = M.split(name);
    local base, suffix = name:match('^(.-)[%s:]+(%a+)$');
    if base ~= nil and M.ROMAN[suffix:lower()] == tier and tier ~= nil then
        return (base:gsub('[%s:]+$', ''));
    end
    return name;
end

return M;
