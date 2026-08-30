local M = {}

local function display_text(value, fallback)
    if type(value) ~= 'string' and type(value) ~= 'number' then
        return fallback
    end
    local result = tostring(value):gsub('%c', ' '):gsub('%s+', ' ')
    result = vim.trim(result)
    return result ~= '' and result or fallback
end

local function author_name(author)
    if type(author) == 'table' then
        local username = display_text(author.username)
        if username then
            return '@' .. username
        end
        local name = display_text(author.name)
        if name then
            return name
        end
    end
    return '?'
end

local function exact_updated_at(value)
    local timestamp = display_text(value, 'unknown')
    return timestamp:gsub('T', ' ', 1):gsub('Z$', ' UTC')
end

function M.merge_request(mr)
    return table.concat({
        '!' .. display_text(mr.iid, '?'),
        author_name(mr.author),
        display_text(mr.title, '(untitled)'),
    }, '\t')
end

function M.preview_header(mr)
    local identity = { 'Merge request !' .. display_text(mr.iid, '?') }
    if mr.draft then
        identity[#identity + 1] = 'DRAFT'
    end
    identity[#identity + 1] = display_text(mr.title, '(untitled)')

    return table.concat(identity, ' · ')
        .. '\nAuthor '
        .. author_name(mr.author)
        .. ' │ '
        .. display_text(mr.source_branch, '?')
        .. ' → '
        .. display_text(mr.target_branch, '?')
        .. ' │ Updated '
        .. exact_updated_at(mr.updated_at)
end

return M
