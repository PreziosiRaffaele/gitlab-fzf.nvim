local M = {}

local function author_name(author)
    if type(author) == 'table' then
        if type(author.username) == 'string' and author.username ~= '' then
            return '@' .. author.username
        end
        if type(author.name) == 'string' and author.name ~= '' then
            return author.name
        end
    end
    return '?'
end

function M.merge_request(mr)
    return string.format(
        '!%d  %s%s  %s  %s -> %s  %s',
        mr.iid,
        mr.draft and '[Draft] ' or '',
        mr.title,
        author_name(mr.author),
        mr.source_branch,
        mr.target_branch,
        mr.updated_at or ''
    )
end

return M
