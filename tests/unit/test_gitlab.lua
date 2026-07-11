local gitlab = require('prview.gitlab')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T['normalizes merge requests'] = function()
    eq(
        gitlab._normalize_mr({
            iid = 2,
            title = 'x',
            project_id = 3,
            source_branch = 'a',
            target_branch = 'b',
            work_in_progress = true,
        }),
        {
            project_id = 3,
            iid = 2,
            title = 'x',
            author = nil,
            source_project_id = nil,
            target_project_id = nil,
            source_branch = 'a',
            target_branch = 'b',
            head_sha = nil,
            updated_at = nil,
            draft = true,
            web_url = nil,
        }
    )
end

T['normalizes statuses and counts hunk lines'] = function()
    local file = gitlab._normalize_file({
        old_path = 'a',
        new_path = 'b',
        renamed_file = true,
        diff = '@@ -1 +1,2 @@\n-old\n+new\n+another',
    })
    eq({ file.status, file.additions, file.deletions }, { 'R', 2, 1 })
end

T['consumes ndjson pages'] = function()
    local result = gitlab._decode_pages('[{"iid":1}]\n[{"iid":2}]\n')
    eq({ result[1].iid, result[2].iid }, { 1, 2 })
end

T['sanitizes credentials'] = function()
    eq(
        gitlab._sanitize('request https://secret@example.com failed token=abc'),
        'request https://example.com failed token=[REDACTED]'
    )
end

return T
