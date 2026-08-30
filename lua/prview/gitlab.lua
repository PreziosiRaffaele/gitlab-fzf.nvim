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
            proc:kill(15)
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

local function error_for(result)
    local detail = sanitize(result.stderr)
    local lower = detail:lower()
    if lower:find('auth') or lower:find('401') then
        return 'GitLab authentication failed. Set GITLAB_TOKEN or run `glab auth login` for this repository host.'
    elseif lower:find('not a git repository') then
        return 'PRView must be run inside a Git repository.'
    elseif lower:find('remote') or lower:find('hostname') then
        return 'No GitLab remote recognized by glab for this repository. Check the remote and `glab auth status`.'
    end
    return 'GitLab request failed' .. (detail ~= '' and ': ' .. detail or '.')
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
        author = nullable(raw.author),
        source_branch = nullable(raw.source_branch) or '',
        target_branch = nullable(raw.target_branch) or '',
        updated_at = nullable(raw.updated_at),
        draft = raw.draft == true or raw.work_in_progress == true,
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
            'projects/:id/merge_requests?state=opened&order_by=updated_at&sort=desc&per_page=100',
            normalize_mr,
            callback
        )
    end

    function transport.get_merge_request_diff(mr, callback)
        local iid = tonumber(mr and mr.iid)
        if not iid or iid < 1 or iid % 1 ~= 0 then
            callback(nil, 'GitLab returned an invalid merge request identifier.')
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

    return transport
end

M._decode_pages = decode_pages
M._normalize_mr = normalize_mr
M._sanitize = sanitize

return M
