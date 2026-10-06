-- An ordered list of rules: the per-job file as a value. Every edit returns a new document;
-- comments and lines that do not parse are kept as raw entries so a save never loses them.
local rule = require('lib.rule');

local M = {};

local function copy_rules(doc)
    local out = {};
    for i, r in ipairs(doc.rules) do out[i] = r; end
    return out;
end

function M.new(rules)
    return { rules = rules or {} };
end

function M.parse(lines)
    local rules = {};
    for _, line in ipairs(lines) do
        local trimmed = line:match('^%s*(.-)%s*$');
        if trimmed:sub(1, 1) == '#' then
            table.insert(rules, { raw = line });
        elseif trimmed ~= '' then
            local r, err = rule.parse(trimmed);
            table.insert(rules, r or { raw = line, error = err });
        end
    end
    return M.new(rules);
end

function M.lines(doc)
    local out = {};
    for _, r in ipairs(doc.rules) do
        table.insert(out, r.raw or rule.line(r));
    end
    return out;
end

function M.same(a, b)
    return table.concat(M.lines(a), '\n') == table.concat(M.lines(b), '\n');
end

function M.add(doc, r)
    local rules = copy_rules(doc);
    table.insert(rules, r);
    return M.new(rules);
end

function M.remove(doc, i)
    if doc.rules[i] == nil then return doc; end
    local rules = copy_rules(doc);
    table.remove(rules, i);
    return M.new(rules);
end

function M.move(doc, from, to)
    if from == to or doc.rules[from] == nil or doc.rules[to] == nil then return doc; end
    local rules = copy_rules(doc);
    local r = table.remove(rules, from);
    table.insert(rules, to, r);
    return M.new(rules);
end

function M.set(doc, i, r)
    if doc.rules[i] == nil then return doc; end
    local rules = copy_rules(doc);
    rules[i] = r;
    return M.new(rules);
end

local function shallow(r)
    local out = {};
    for k, v in pairs(r) do out[k] = v; end
    return out;
end

function M.toggle(doc, i)
    local r = doc.rules[i];
    if r == nil or r.raw ~= nil then return doc; end
    local flipped = shallow(r);
    flipped.enabled = not r.enabled;
    return M.set(doc, i, flipped);
end

function M.duplicate(doc, i)
    local r = doc.rules[i];
    if r == nil or r.raw ~= nil then return doc; end
    local rules = copy_rules(doc);
    table.insert(rules, i + 1, r);
    return M.new(rules);
end

return M;
