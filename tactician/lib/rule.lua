-- One rule as a table and as the one line a player could type or read in the saved file:
--   [off] <scope> <if>[ and|or <if>] <then> [retry:<seconds>]
--   if: <condition>[:<number or name>]      then: <reaction>[:<selector>]:<name> | rattack
-- Names with a space or colon are quoted. Parsing validates against lib/vocab, so a line
-- that parses is a rule the engine can run.
local vocab = require('lib.vocab');

local M = {};

-- rule = { enabled, scope, conds = { { key, arg } , ... }, logic ('and'|'or' with two conds),
--          act = { reaction, selector, arg }, retry }
function M.blank()
    return { enabled = true, scope = 'self', conds = { { key = 'always' } },
             act = { reaction = 'ma', selector = 'specific', arg = '' }, retry = 0 };
end

-- Splits on `sep` outside double quotes and strips the quotes.
local function split(text, sep)
    local parts, cur, quoted = {}, {}, false;
    for i = 1, #text do
        local ch = text:sub(i, i);
        if ch == '"' then
            quoted = not quoted;
        elseif ch == sep and not quoted then
            table.insert(parts, table.concat(cur));
            cur = {};
        else
            table.insert(cur, ch);
        end
    end
    table.insert(parts, table.concat(cur));
    return parts;
end

local function tokens(line)
    local out = {};
    for _, t in ipairs(split(line, ' ')) do
        if t ~= '' then table.insert(out, t); end
    end
    return out;
end

local function quote(name)
    if name:find('[ :]') then return '"' .. name .. '"'; end
    return name;
end

local function check_condition(cond, scope)
    local c = vocab.condition(cond.key);
    if c == nil then return ('unknown condition "%s"'):format(tostring(cond.key)); end
    if c.arg == 'none' and cond.arg ~= nil then return c.key .. ' takes no argument'; end
    if c.arg == 'number' then
        if type(cond.arg) ~= 'number' then return c.key .. ' needs a number'; end
        if cond.arg < c.min or cond.arg > c.max then return ('%s takes %d to %d%s'):format(c.key, c.min, c.max, c.unit); end
    end
    if c.arg == 'status' and (type(cond.arg) ~= 'string' or cond.arg == '') then return c.key .. ' needs a name'; end
    if not vocab.fits(c.key, scope) then
        return ('%s cannot be read for %s'):format(c.key, vocab.target(scope).label:lower());
    end
    return nil;
end

-- nil when the rule is sound, else what is wrong with it
function M.check(r)
    local scope = vocab.target(r.scope);
    if scope == nil then return ('unknown scope "%s"'):format(tostring(r.scope)); end
    if type(r.conds) ~= 'table' or #r.conds == 0 or #r.conds > 2 then return 'one or two conditions'; end
    for _, cond in ipairs(r.conds) do
        local err = check_condition(cond, r.scope);
        if err then return err; end
    end
    if #r.conds == 2 and r.logic ~= 'and' and r.logic ~= 'or' then return 'a second condition needs and or or'; end
    if #r.conds == 1 and r.logic ~= nil then return 'and/or without a second condition'; end
    local act = r.act or {};
    local reaction = vocab.reaction(act.reaction);
    if reaction == nil then return ('unknown action "%s"'):format(tostring(act.reaction)); end
    if not vocab.allows(act.reaction, act.selector) then
        if act.selector == nil then return act.reaction .. ' needs a name'; end
        if #reaction.selectors == 0 then return act.reaction .. ' takes no argument'; end
        return ('%s does not take %s'):format(act.reaction, tostring(act.selector));
    end
    if act.selector ~= nil and (type(act.arg) ~= 'string' or act.arg == '') then return act.reaction .. ' needs a name'; end
    if act.selector == nil and act.arg ~= nil then return act.reaction .. ' takes no argument'; end
    if type(r.retry) ~= 'number' or r.retry < 0 then return 'retry needs a number of seconds'; end
    return nil;
end

local function parse_condition(token)
    local parts = split(token, ':');
    local cond = { key = parts[1] };
    local c = vocab.condition(cond.key);
    if c == nil then return cond; end
    if parts[2] ~= nil then
        if c.arg == 'number' then cond.arg = tonumber(parts[2]) or parts[2]; else cond.arg = parts[2]; end
    end
    return cond;
end

local function parse_action(token)
    local parts = split(token, ':');
    local act = { reaction = parts[1] };
    local reaction = vocab.reaction(act.reaction);
    if reaction == nil or #parts == 1 then
        if #parts > 1 then act.arg = parts[2]; end
        return act;
    end
    if #parts >= 3 and vocab.selector(parts[2]) ~= nil then
        act.selector = parts[2];
        act.arg = table.concat(parts, ':', 3);
    else
        act.selector = 'specific';
        act.arg = table.concat(parts, ':', 2);
    end
    return act;
end

-- rule or nil plus the reason
function M.parse(line)
    local t = tokens(line);
    local r = { enabled = true, conds = {}, retry = 0 };
    local i = 1;
    if t[i] == 'off' then r.enabled = false; i = i + 1; end
    if t[i] == nil then return nil, 'a rule starts with its scope'; end
    r.scope = t[i]; i = i + 1;
    if vocab.target(r.scope) == nil then return nil, ('unknown scope "%s"'):format(r.scope); end
    if t[i] == nil then return nil, 'a condition follows the scope'; end
    table.insert(r.conds, parse_condition(t[i])); i = i + 1;
    if t[i] == 'and' or t[i] == 'or' then
        r.logic = t[i]; i = i + 1;
        if t[i] == nil then return nil, 'a second condition follows ' .. r.logic; end
        local second = parse_condition(t[i]);
        if vocab.condition(second.key) == nil then return nil, 'a second condition follows ' .. r.logic; end
        table.insert(r.conds, second); i = i + 1;
    end
    if t[i] == nil then return nil, 'an action follows the condition'; end
    r.act = parse_action(t[i]); i = i + 1;
    if t[i] ~= nil and t[i]:match('^retry:') then
        local n = tonumber(t[i]:sub(7));
        if n == nil then return nil, 'retry needs a number of seconds'; end
        r.retry = n; i = i + 1;
    end
    if t[i] ~= nil then return nil, ('extra text after the action: "%s"'):format(t[i]); end
    local err = M.check(r);
    if err then return nil, err; end
    return r;
end

local function condition_text(cond)
    if cond.arg == nil then return cond.key; end
    if type(cond.arg) == 'number' then return ('%s:%d'):format(cond.key, cond.arg); end
    return cond.key .. ':' .. quote(cond.arg);
end

-- the line a parsed rule came from; the file is written in this form
function M.line(r)
    local parts = {};
    if not r.enabled then table.insert(parts, 'off'); end
    table.insert(parts, r.scope);
    table.insert(parts, condition_text(r.conds[1]));
    if r.conds[2] then
        table.insert(parts, r.logic);
        table.insert(parts, condition_text(r.conds[2]));
    end
    local act = r.act;
    if act.selector == nil then
        table.insert(parts, act.reaction);
    elseif act.selector == 'specific' then
        table.insert(parts, act.reaction .. ':' .. quote(act.arg));
    else
        table.insert(parts, act.reaction .. ':' .. act.selector .. ':' .. quote(act.arg));
    end
    if r.retry > 0 then table.insert(parts, ('retry:%d'):format(r.retry)); end
    return table.concat(parts, ' ');
end

return M;
