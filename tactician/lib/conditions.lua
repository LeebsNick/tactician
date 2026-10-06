-- Whether a condition holds for a subject. env = { random = fn() -> [0,1), status = fn(name) -> id }.
-- A reading the subject does not expose (a monster's MP, a pet's statuses) never holds.
local M = {};

local function status_id(cond, env)
    if type(cond.arg) ~= 'string' then return nil; end
    return env.status(cond.arg);
end

local TESTS = {
    always      = function() return true; end,
    hpp_lt      = function(c, s) return s.hpp ~= nil and s.hpp < c.arg; end,
    hpp_gte     = function(c, s) return s.hpp ~= nil and s.hpp >= c.arg; end,
    mpp_lt      = function(c, s) return s.mpp ~= nil and s.mpp < c.arg; end,
    tp_lt       = function(c, s) return s.tp ~= nil and s.tp < c.arg; end,
    tp_gte      = function(c, s) return s.tp ~= nil and s.tp >= c.arg; end,
    hp_missing  = function(c, s) return s.hp_missing ~= nil and s.hp_missing >= c.arg; end,
    casting_ma  = function(_, s) return s.casting == true; end,
    readying_ms = function(_, s) return s.readying == true; end,
    random      = function(c, _, env) return env.random() * 100 < c.arg; end,
    status      = function(c, s, env)
        local id = status_id(c, env);
        return id ~= nil and s.buffs ~= nil and s.buffs[id] == true;
    end,
    not_status  = function(c, s, env)
        local id = status_id(c, env);
        return id ~= nil and s.buffs ~= nil and s.buffs[id] ~= true;
    end,
};

function M.holds(cond, subject, env)
    local test = TESTS[cond.key];
    return test ~= nil and test(cond, subject, env) == true;
end

-- the rule's one or two conditions under its logic word
function M.all(r, subject, env)
    local first = M.holds(r.conds[1], subject, env);
    if r.conds[2] == nil then return first; end
    local second = M.holds(r.conds[2], subject, env);
    if r.logic == 'or' then return first or second; end
    return first and second;
end

return M;
