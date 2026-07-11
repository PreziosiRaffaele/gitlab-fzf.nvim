local M = {}

local function author(mr)
    if type(mr.author) == 'table' then
        return mr.author.username or mr.author.name or '?'
    end
    return mr.author or '?'
end

function M.merge_request(mr)
    return string.format(
        '!%d  %s%s  @%s  %s -> %s  %s',
        mr.iid,
        mr.draft and '[Draft] ' or '',
        mr.title,
        author(mr),
        mr.source_branch,
        mr.target_branch,
        mr.updated_at or ''
    )
end

function M.path(file)
    if file.status == 'R' then
        return file.old_path .. ' -> ' .. file.new_path
    end
    return file.status == 'D' and file.old_path or file.new_path
end

function M.changed_file(file)
    return string.format('%s  %s', file.status, M.path(file))
end

function M.file_summary(files)
    local added, deleted, complete = 0, 0, true
    local lines = {}
    for _, file in ipairs(files) do
        local a, d = file.additions, file.deletions
        if a == nil or d == nil then
            complete = false
        end
        added = added + (a or 0)
        deleted = deleted + (d or 0)
        lines[#lines + 1] = string.format('%s  +%s -%s   %s', file.status, a or '?', d or '?', M.path(file))
    end
    local suffix = complete and '' or ' (known lines only; total incomplete)'
    return string.format('%d files  +%d -%d%s\n\n%s', #files, added, deleted, suffix, table.concat(lines, '\n'))
end

return M
