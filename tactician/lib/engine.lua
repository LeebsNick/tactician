-- Reads the rules top down and picks the first one that fires: its scope resolves to a subject,
-- its conditions hold for that subject and its action can be used right now. Per-rule retry
-- and backoff live in a small state the entry point keeps between ticks.
local actions    = require('lib.actions');
local catalog    = require('lib.catalog');
local command    = require('lib.command');
local conditions = require('lib.conditions');
local scope        = require('lib.scope');

local M = {};

M.BACKOFF = 5;  -- seconds a rule rests after the game refused its command

function M.new()
    return { fired = {}, backoff = {} };
end

local function env_for(cat, random)
    return { random = random or math.random, status = function(name) return catalog.status(cat, name); end };
end

local function resting(r, i, state, now)
    local last, off = state.fired[i], state.backoff[i];
    if last and r.retry > 0 and now - last < r.retry then return true; end
    if off and now < off then return true; end
    return false;
end

-- { index, rule, subject, action, command } or nil
function M.pick(doc, cat, snap, state, random)
    local env = env_for(cat, random);
    for i, r in ipairs(doc.rules) do
        if r.raw == nil and r.enabled and not resting(r, i, state, snap.now) then
            for _, subject in ipairs(scope.candidates(r.scope, snap)) do
                if conditions.all(r, subject, env) then
                    local a = actions.resolve(r.act, subject, cat, snap);
                    if a then
                        return { index = i, rule = r, subject = subject, action = a, command = command.text(a) };
                    end
                end
            end
        end
    end
    return nil;
end

local function with(state, field, i, value)
    local out = { fired = {}, backoff = {} };
    for k, v in pairs(state.fired) do out.fired[k] = v; end
    for k, v in pairs(state.backoff) do out.backoff[k] = v; end
    out[field][i] = value;
    return out;
end

function M.fired(state, i, now)   return with(state, 'fired', i, now); end
function M.refused(state, i, now) return with(state, 'backoff', i, now + M.BACKOFF); end

local STATIC = { '^unknown', '^not learned', '^needs ', '^not for', '^cannot target' };

-- Why a rule can never fire as written (a name the client does not know, a spell not learned,
-- a level not reached, an action aimed where it cannot land), or nil for one that merely
-- waits on MP, recasts or a target. Shown beside the rule in the editor.
function M.inert(r, cat, snap)
    if r.raw then return r.error; end
    local subjects = scope.candidates(r.scope, snap);
    if #subjects == 0 then subjects = { scope.sample(r.scope) }; end
    local reason;
    for _, s in ipairs(subjects) do
        local a, why = actions.resolve(r.act, s, cat, snap);
        if a then return nil; end
        reason = reason or why;
    end
    for _, pattern in ipairs(STATIC) do
        if reason and reason:find(pattern) then return reason; end
    end
    return nil;
end

return M;
