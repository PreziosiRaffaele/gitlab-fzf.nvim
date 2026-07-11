local M = {}

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

local function line_counts(patch)
    if type(patch) ~= 'string' or patch == '' then
        return nil, nil
    end
    local additions, deletions = 0, 0
    for line in (patch .. '\n'):gmatch('(.-)\n') do
        if line:sub(1, 1) == '+' and line:sub(1, 3) ~= '+++' then
            additions = additions + 1
        end
        if line:sub(1, 1) == '-' and line:sub(1, 3) ~= '---' then
            deletions = deletions + 1
        end
    end
    return additions, deletions
end

local function normalize_mr(raw)
    return {
        project_id = raw.project_id or raw.target_project_id,
        iid = raw.iid,
        title = raw.title or '',
        author = raw.author,
        source_project_id = raw.source_project_id,
        target_project_id = raw.target_project_id,
        source_branch = raw.source_branch or '',
        target_branch = raw.target_branch or '',
        head_sha = raw.sha or (raw.diff_refs and raw.diff_refs.head_sha),
        updated_at = raw.updated_at,
        draft = raw.draft == true or raw.work_in_progress == true,
        web_url = raw.web_url,
    }
end

local function normalize_file(raw)
    local renamed = raw.renamed_file == true
    local status = raw.new_file and 'A' or raw.deleted_file and 'D' or renamed and 'R' or 'M'
    local patch = raw.diff or raw.patch
    local additions, deletions = line_counts(patch)
    local unavailable = raw.binary or raw.too_large or raw.collapsed
    if unavailable then
        additions, deletions = nil, nil
    end
    return {
        old_path = raw.old_path,
        new_path = raw.new_path,
        status = status,
        patch = patch,
        additions = additions,
        deletions = deletions,
        renamed = renamed,
        deleted = raw.deleted_file == true,
        generated = raw.generated_file == true,
        collapsed = raw.collapsed == true,
        too_large = raw.too_large == true,
        binary = raw.binary == true,
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

    function transport.list_changed_files(mr, callback)
        local project = assert(mr.project_id or mr.target_project_id, 'merge request project identity is required')
        return request(
            string.format('projects/%s/merge_requests/%s/diffs?per_page=100', project, mr.iid),
            normalize_file,
            callback
        )
    end

    return transport
end

M._decode_pages = decode_pages
M._normalize_mr = normalize_mr
M._normalize_file = normalize_file
M._sanitize = sanitize

return M
