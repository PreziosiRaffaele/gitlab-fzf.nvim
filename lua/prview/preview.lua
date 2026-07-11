local M = {}

local function usable(file)
    if file.binary then
        return nil, 'Binary change; no textual patch is available.'
    end
    if file.too_large or file.collapsed then
        return nil, 'Patch is oversized or collapsed by GitLab.'
    end
    if type(file.patch) ~= 'string' or file.patch == '' then
        return nil, 'Patch unavailable for this change.'
    end
    return true
end

function M.patch(file)
    local ok, message = usable(file)
    if not ok then
        return nil, message
    end
    local old = file.status == 'A' and '/dev/null' or 'a/' .. file.old_path
    local new = file.status == 'D' and '/dev/null' or 'b/' .. file.new_path
    local header = string.format('diff --git a/%s b/%s\n--- %s\n+++ %s\n', file.old_path, file.new_path, old, new)
    return header .. file.patch
end

function M.render(file, runner, callback)
    local patch, message = M.patch(file)
    if not patch then
        callback(message, 'text')
        return
    end
    runner({ 'delta', '--color-only' }, { stdin = patch, text = true }, function(result)
        if result and result.code == 0 and result.stdout and result.stdout ~= '' then
            callback(result.stdout, 'ansi')
        else
            callback(patch, 'diff')
        end
    end)
end

return M
