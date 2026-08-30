local gitlab = require('gitlab-fzf.gitlab')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T['normalizes merge requests for the picker'] = function()
    eq(
        gitlab._normalize_mr({
            iid = 2,
            title = 'Review me',
            description = 'Summary',
            project_id = 3,
            author = { username = 'alice' },
            reviewers = { { username = 'bob' } },
            labels = { 'enhancement' },
            source_branch = 'feature',
            target_branch = 'main',
            updated_at = '2026-08-30T10:00:00Z',
            work_in_progress = true,
            detailed_merge_status = 'draft_status',
            web_url = 'https://gitlab.example.com/group/project/-/merge_requests/2',
        }),
        {
            project_id = 3,
            iid = 2,
            title = 'Review me',
            description = 'Summary',
            author = { username = 'alice' },
            reviewers = { { username = 'bob' } },
            labels = { 'enhancement' },
            source_branch = 'feature',
            target_branch = 'main',
            updated_at = '2026-08-30T10:00:00Z',
            draft = true,
            detailed_merge_status = 'draft_status',
            web_url = 'https://gitlab.example.com/group/project/-/merge_requests/2',
        }
    )
end

T['lists every page of open merge requests'] = function()
    local argv, result
    local transport = gitlab.new({
        runner = function(value, _, callback)
            argv = value
            callback({ code = 0, stdout = '[{"iid":1,"project_id":3}]\n[{"iid":2,"project_id":3}]\n' })
        end,
    })
    transport.list_merge_requests(function(value)
        result = value
    end)
    eq(argv, {
        'glab',
        'api',
        '--paginate',
        '--output',
        'ndjson',
        'projects/:fullpath/merge_requests?state=opened&order_by=updated_at&sort=desc&per_page=100',
    })
    eq({ result[1].iid, result[2].iid }, { 1, 2 })
end

T['retrieves the raw merge request diff'] = function()
    local argv, opts, result
    local transport = gitlab.new({
        runner = function(value, options, callback)
            argv, opts = value, options
            callback({ code = 0, stdout = 'diff --git a/x b/x\n' })
            return { cancel = function() end }
        end,
    })
    transport.get_merge_request_diff({ iid = 7 }, function(value, err)
        result = { value, err }
    end)
    eq(argv, { 'glab', 'mr', 'diff', '7', '--raw', '--color=never' })
    eq(opts, { text = true })
    eq(result, { 'diff --git a/x b/x\n', nil })
end

T['checks out the merge request source branch'] = function()
    local argv, opts, result
    local transport = gitlab.new({
        runner = function(value, options, callback)
            argv, opts = value, options
            callback({ code = 0, stdout = "Switched to branch 'feature'\n" })
            return { cancel = function() end }
        end,
    })
    transport.checkout_merge_request({ iid = 7 }, function(value, err)
        result = { value, err }
    end)
    eq(argv, { 'glab', 'mr', 'checkout', '7' })
    eq(opts, { text = true })
    eq(result, { "Switched to branch 'feature'\n", nil })
end

T['rejects an invalid merge request identifier before running glab'] = function()
    local called, err
    local transport = gitlab.new({
        runner = function()
            called = true
        end,
    })
    transport.get_merge_request_diff({ iid = '--help' }, function(_, value)
        err = value
    end)
    eq(called, nil)
    eq(err, 'GitLab returned an invalid merge request identifier.')
end

T['reports and sanitizes raw diff failures'] = function()
    local err
    local transport = gitlab.new({
        runner = function(_, _, callback)
            callback({ code = 1, stderr = 'request https://secret@example.com failed token=abc' })
        end,
    })
    transport.get_merge_request_diff({ iid = 7 }, function(_, value)
        err = value
    end)
    eq(err, 'GitLab request failed: request https://example.com failed token=[REDACTED]')
end

T['reports and sanitizes checkout failures'] = function()
    local err
    local transport = gitlab.new({
        runner = function(_, _, callback)
            callback({ code = 1, stderr = 'request https://secret@example.com failed token=abc' })
        end,
    })
    transport.checkout_merge_request({ iid = 7 }, function(_, value)
        err = value
    end)
    eq(err, 'Unable to check out merge request: request https://example.com failed token=[REDACTED]')
end

T['rejects an invalid checkout identifier before running glab'] = function()
    local called, err
    local transport = gitlab.new({
        runner = function()
            called = true
        end,
    })
    transport.checkout_merge_request({ iid = '--help' }, function(_, value)
        err = value
    end)
    eq(called, nil)
    eq(err, 'GitLab returned an invalid merge request identifier.')
end

T['reports gateway failures without exposing the HTML response'] = function()
    local err
    local transport = gitlab.new({
        runner = function(_, _, callback)
            callback({
                code = 1,
                stderr = '502 failed to parse unknown error format: <html><title>502 Bad Gateway</title></html>',
            })
        end,
    })
    transport.get_merge_request_diff({ iid = 7 }, function(_, value)
        err = value
    end)
    eq(err, 'GitLab gateway returned 502 Bad Gateway. Check the GitLab host or reverse proxy and retry.')
end

T['rejects malformed paginated JSON'] = function()
    local result, err = gitlab._decode_pages('{broken')
    eq(result, nil)
    eq(err, 'GitLab returned malformed or unsupported JSON.')
end

return T
