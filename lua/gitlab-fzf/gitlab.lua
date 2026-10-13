local M = {}

local function nullable(value)
    if value == vim.NIL then
        return nil
    end
    return value
end

local function default_runner(argv, opts, callback)
    local proc = vim.system(argv, opts, function(result)
        vim.schedule(function()
            callback(result)
        end)
    end)
    return {
        cancel = function()
            pcall(proc.kill, proc, 15)
        end,
    }
end

local function sanitize(value)
    value = tostring(value or '')
    value = value:gsub('https?://[^%s@]+@', 'https://')
    value = value:gsub('([Tt][Oo][Kk][Ee][Nn]%s*[:=]%s*)[^%s]+', '%1[REDACTED]')
    value = value:gsub('([Aa][Uu][Tt][Hh][Oo][Rr][Ii][Zz][Aa][Tt][Ii][Oo][Nn]%s*[:=]%s*)[^%s]+', '%1[REDACTED]')
    return vim.trim(value)
end

local function has_any(text, patterns)
    for _, pattern in ipairs(patterns) do
        if text:find(pattern) then
            return true
        end
    end
    return false
end

-- Match specific glab and HTTP phrases; broad words such as "auth" or "remote"
-- also appear in unrelated output like "author" or Git's "remote:" prefix.
local function error_for(result, fallback)
    local detail = sanitize(result.stderr)
    local lower = detail:lower()
    if lower:find('%f[%d]502%f[%D]') and lower:find('bad gateway', 1, true) then
        return 'GitLab gateway returned 502 Bad Gateway. Check the GitLab host or reverse proxy and retry.'
    elseif lower:find('not a git repository', 1, true) then
        return 'GitLab Fzf must be run inside a Git repository.'
    elseif has_any(lower, { 'none of the git remotes', 'no git remotes', 'known gitlab host' }) then
        return 'No GitLab remote recognized by glab for this repository. Check the remote and `glab auth status`.'
    elseif
        has_any(lower, { '%f[%d]401%f[%D]', 'unauthorized', 'authentication', 'not authenticated', 'invalid token' })
    then
        return 'GitLab authentication failed. Set GITLAB_TOKEN or run `glab auth login` for this repository host.'
    elseif has_any(lower, { '%f[%d]403%f[%D]', 'forbidden', 'insufficient scope' }) then
        return 'GitLab denied access. Check your role in this project and the token scopes.'
    end
    return (fallback or 'GitLab request failed') .. (detail ~= '' and ': ' .. detail or '.')
end

local function merge_request_iid(mr)
    local iid = tonumber(mr and mr.iid)
    if not iid or iid < 1 or iid % 1 ~= 0 then
        return nil, 'GitLab returned an invalid merge request identifier.'
    end
    return iid
end

-- Accept an array, NDJSON, or the concatenated arrays emitted by paginated glab.
local function decode_pages(output)
    local ok, decoded = pcall(vim.json.decode, output)
    if ok then
        if vim.islist(decoded) then
            return decoded
        end
        return { decoded }
    end
    local items = {}
    for line in output:gmatch('[^\r\n]+') do
        local line_ok, page = pcall(vim.json.decode, line)
        if not line_ok then
            return nil, 'GitLab returned malformed or unsupported JSON.'
        end
        if vim.islist(page) then
            vim.list_extend(items, page)
        else
            items[#items + 1] = page
        end
    end
    if #items == 0 and vim.trim(output) ~= '' then
        return nil, 'GitLab returned malformed or unsupported JSON.'
    end
    return items
end

local function normalize_mr(raw)
    return {
        project_id = raw.project_id or raw.target_project_id,
        iid = raw.iid,
        title = nullable(raw.title) or '',
        description = nullable(raw.description) or '',
        author = nullable(raw.author),
        reviewers = type(raw.reviewers) == 'table' and raw.reviewers or {},
        labels = type(raw.labels) == 'table' and raw.labels or {},
        source_branch = nullable(raw.source_branch) or '',
        target_branch = nullable(raw.target_branch) or '',
        updated_at = nullable(raw.updated_at),
        draft = raw.draft == true or raw.work_in_progress == true,
        detailed_merge_status = nullable(raw.detailed_merge_status),
        web_url = nullable(raw.web_url),
    }
end

function M.new(opts)
    opts = opts or {}
    local runner = opts.runner or default_runner
    local transport = {}

    local function request(path, normalize, callback)
        return runner({ 'glab', 'api', '--paginate', '--output', 'ndjson', path }, { text = true }, function(result)
            if result.code ~= 0 then
                callback(nil, error_for(result))
                return
            end
            local raw, err = decode_pages(result.stdout or '')
            if not raw then
                callback(nil, err)
                return
            end
            local normalized = {}
            for _, item in ipairs(raw) do
                normalized[#normalized + 1] = normalize(item)
            end
            callback(normalized, nil)
        end)
    end

    function transport.list_merge_requests(callback)
        return request(
            'projects/:fullpath/merge_requests?state=opened&order_by=updated_at&sort=desc&per_page=100',
            normalize_mr,
            callback
        )
    end

    function transport.get_merge_request_diff(mr, callback)
        local iid, err = merge_request_iid(mr)
        if not iid then
            callback(nil, err)
            return { cancel = function() end }
        end
        return runner(
            { 'glab', 'mr', 'diff', tostring(iid), '--raw', '--color=never' },
            { text = true },
            function(result)
                if result.code ~= 0 then
                    callback(nil, error_for(result))
                    return
                end
                callback(result.stdout or '', nil)
            end
        )
    end

    function transport.checkout_merge_request(mr, callback)
        local iid, err = merge_request_iid(mr)
        if not iid then
            callback(nil, err)
            return { cancel = function() end }
        end
        return runner({ 'glab', 'mr', 'checkout', tostring(iid) }, { text = true }, function(result)
            if result.code ~= 0 then
                callback(nil, error_for(result, 'Unable to check out merge request'))
                return
            end
            callback(result.stdout or '', nil)
        end)
    end

    return transport
end

M._decode_pages = decode_pages
M._normalize_mr = normalize_mr
M._sanitize = sanitize

return M
