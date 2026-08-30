local format = require('gitlab-fzf.format')

local M = {}

local DESCRIPTION_LIMIT = 240

local function display_text(value, fallback)
    if type(value) ~= 'string' and type(value) ~= 'number' then
        return fallback
    end
    local result = tostring(value):gsub('%c', ' '):gsub('%s+', ' ')
    result = vim.trim(result)
    return result ~= '' and result or fallback
end

local function user_name(user)
    if type(user) ~= 'table' then
        return nil
    end
    local username = display_text(user.username)
    if username then
        return '@' .. username
    end
    return display_text(user.name)
end

local function description_excerpt(description)
    if type(description) ~= 'string' then
        return nil
    end

    local lines = {}
    description = description:gsub('\r\n', '\n'):gsub('\r', '\n')
    for line in (description .. '\n'):gmatch('(.-)\n') do
        if line:match('^%s*$') then
            if #lines > 0 then
                break
            end
        else
            lines[#lines + 1] = line
        end
    end

    local excerpt = display_text(table.concat(lines, ' '))
    if not excerpt then
        return nil
    end
    if vim.fn.strchars(excerpt) > DESCRIPTION_LIMIT then
        return vim.fn.strcharpart(excerpt, 0, DESCRIPTION_LIMIT - 1) .. '…'
    end
    return excerpt
end

local escapes = {
    a = '\a',
    b = '\b',
    f = '\f',
    n = '\n',
    r = '\r',
    t = '\t',
    v = '\v',
    ['\\'] = '\\',
    ['"'] = '"',
}

local function parse_token(value, position)
    position = position or 1
    while value:sub(position, position) == ' ' do
        position = position + 1
    end
    if position > #value then
        return nil, position
    end

    if value:sub(position, position) ~= '"' then
        local finish = value:find(' ', position, true) or (#value + 1)
        return value:sub(position, finish - 1), finish
    end

    position = position + 1
    local result = {}
    while position <= #value do
        local char = value:sub(position, position)
        if char == '"' then
            return table.concat(result), position + 1
        elseif char ~= '\\' then
            result[#result + 1] = char
            position = position + 1
        else
            local escaped = value:sub(position + 1, position + 1)
            local replacement = escapes[escaped]
            if replacement then
                result[#result + 1] = replacement
                position = position + 2
            elseif escaped:match('[0-7]') then
                local octal = value:sub(position + 1):match('^([0-7][0-7]?[0-7]?)')
                result[#result + 1] = string.char(tonumber(octal, 8))
                position = position + 1 + #octal
            else
                result[#result + 1] = escaped
                position = position + 2
            end
        end
    end
    return nil, position
end

local function changed_path(line)
    local values = line:match('^diff %-%-git (.+)$')
    if not values then
        return nil
    end
    local _, position = parse_token(values)
    local path = parse_token(values, position)
    if path and path:sub(1, 2) == 'b/' then
        path = path:sub(3)
    end
    return path ~= '' and path or nil
end

local function changed_areas(diff)
    if type(diff) ~= 'string' or diff == '' then
        return {}, 0
    end

    local areas, paths = {}, {}
    for line in diff:gmatch('[^\n]+') do
        local path = changed_path(line:gsub('\r$', ''))
        if path and not paths[path] then
            paths[path] = true
            local area = path:match('^([^/]+)/') or '[root]'
            area = display_text(area, '[root]')
            areas[area] = (areas[area] or 0) + 1
        end
    end

    local result = {}
    for name, count in pairs(areas) do
        result[#result + 1] = { name = name, count = count }
    end
    table.sort(result, function(left, right)
        if left.name == '[root]' or right.name == '[root]' then
            return left.name == '[root]' and right.name ~= '[root]'
        end
        return left.name < right.name
    end)
    return result, vim.tbl_count(paths)
end

local function list_names(values, formatter)
    if type(values) ~= 'table' then
        return nil
    end
    local names = {}
    for _, value in ipairs(values) do
        local name = formatter(value)
        if name then
            names[#names + 1] = name
        end
    end
    return #names > 0 and table.concat(names, ', ') or nil
end

local function status(mr)
    if mr.draft == true then
        return 'draft'
    end
    local value = display_text(mr.detailed_merge_status)
    return value and value:gsub('_', ' ') or nil
end

function M.render(mr, diff, opts)
    mr = type(mr) == 'table' and mr or {}
    opts = opts or {}

    local lines = {
        string.format('!%s  %s', display_text(mr.iid, '?'), display_text(mr.title, '(untitled)')),
    }
    local details = {
        user_name(mr.author) or '?',
        string.format('%s → %s', display_text(mr.source_branch, '?'), display_text(mr.target_branch, '?')),
    }
    local merge_status = status(mr)
    if merge_status then
        details[#details + 1] = merge_status
    end
    details[#details + 1] = 'updated ' .. format.friendly_updated_at(mr.updated_at, opts.now)
    lines[#lines + 1] = table.concat(details, ' · ')

    local reviewers = list_names(mr.reviewers, user_name)
    if reviewers then
        lines[#lines + 1] = 'Reviewers: ' .. reviewers
    end
    local labels = list_names(mr.labels, function(label)
        return display_text(type(label) == 'table' and label.name or label)
    end)
    if labels then
        lines[#lines + 1] = 'Labels: ' .. labels
    end
    local excerpt = description_excerpt(mr.description)
    if excerpt then
        lines[#lines + 1] = 'Summary: ' .. excerpt
    end

    local areas, file_count = changed_areas(diff)
    if #areas > 0 then
        lines[#lines + 1] = ''
        lines[#lines + 1] = string.format('Changed areas · %d %s', file_count, file_count == 1 and 'file' or 'files')
        for _, area in ipairs(areas) do
            lines[#lines + 1] =
                string.format('  %s · %d %s', area.name, area.count, area.count == 1 and 'file' or 'files')
        end
    end

    return table.concat(lines, '\n')
end

M._changed_areas = changed_areas
M._description_excerpt = description_excerpt

return M
