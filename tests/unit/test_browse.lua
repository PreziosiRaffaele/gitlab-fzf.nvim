local browse = require('gitlab-fzf.browse')
local format = require('gitlab-fzf.format')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local mr = {
    project_id = 1,
    iid = 2,
    title = 'MR',
    source_branch = 'feature',
    target_branch = 'main',
}

local function context(overrides)
    local handlers
    local ctx = {
        transport = {
            list_merge_requests = function(callback)
                callback({ mr })
            end,
        },
        renderer = {
            render = function(diff, callback)
                callback('rendered: ' .. diff, 'ansi')
            end,
        },
        summary = {
            render = function(_, diff)
                return diff and 'summary with diff' or 'summary'
            end,
        },
        picker = {
            pick_merge_request = function(_, value)
                handlers = value
            end,
        },
        notify = function() end,
        open_url = function() end,
    }
    return vim.tbl_deep_extend('force', ctx, overrides or {}), function()
        return handlers
    end
end

T['loads, renders, and caches the focused merge request diff'] = function()
    local diff_calls, render_calls = 0, 0
    local ctx, get_handlers = context({
        transport = {
            get_merge_request_diff = function(_, callback)
                diff_calls = diff_calls + 1
                callback('raw diff')
            end,
        },
        renderer = {
            render = function(diff, callback)
                render_calls = render_calls + 1
                eq(diff, 'raw diff')
                callback('colored diff', 'ansi')
            end,
        },
    })
    browse.start(ctx)
    local handlers = get_handlers()
    local preview
    handlers.focus(mr, function(content, syntax)
        preview = { content, syntax }
    end)
    eq(preview, { 'summary with diff\n\nDiff\ncolored diff', 'ansi' })
    handlers.focus(mr, function(content, syntax)
        preview = { content, syntax }
    end)
    eq(preview, { 'summary with diff\n\nDiff\ncolored diff', 'ansi' })
    eq(diff_calls, 1)
    eq(render_calls, 1)
end

T['retries a failed diff request on refocus'] = function()
    local calls = 0
    local ctx, get_handlers = context({
        transport = {
            get_merge_request_diff = function(_, callback)
                calls = calls + 1
                if calls == 1 then
                    callback(nil, 'diff request failed')
                else
                    callback('raw diff')
                end
            end,
        },
    })
    browse.start(ctx)
    local handlers = get_handlers()
    local preview
    handlers.focus(mr, function(content, syntax)
        preview = { content, syntax }
    end)
    eq(preview, { 'summary\n\nDiff\ndiff request failed', 'text' })
    handlers.focus(mr, function(content, syntax)
        preview = { content, syntax }
    end)
    eq(preview, { 'summary with diff\n\nDiff\nrendered: raw diff', 'ansi' })
    eq(calls, 2)
end

T['moving focus cancels an active request and ignores its late callback'] = function()
    local handlers, first_callback, second_callback, first_cancelled
    local other = vim.tbl_extend('force', mr, { iid = 3 })
    browse.start({
        transport = {
            list_merge_requests = function(callback)
                callback({ mr, other })
            end,
            get_merge_request_diff = function(value, callback)
                if value.iid == mr.iid then
                    first_callback = callback
                    return {
                        cancel = function()
                            first_cancelled = true
                        end,
                    }
                end
                second_callback = callback
                return { cancel = function() end }
            end,
        },
        renderer = {
            render = function(diff, callback)
                callback('rendered: ' .. diff, 'diff')
            end,
        },
        summary = {
            render = function(_, diff)
                return diff and 'summary with diff' or 'summary'
            end,
        },
        picker = {
            pick_merge_request = function(_, value)
                handlers = value
            end,
        },
        notify = function() end,
        open_url = function() end,
    })
    local first_preview, second_preview
    handlers.focus(mr, function(content)
        first_preview = content
    end)
    handlers.focus(other, function(content)
        second_preview = content
    end)
    first_callback('late diff')
    second_callback('current diff')
    eq(first_cancelled, true)
    eq(first_preview, 'summary\n\nDiff\nLoading merge request diff…')
    eq(second_preview, 'summary with diff\n\nDiff\nrendered: current diff')
end

T['closing the picker cancels active delta rendering'] = function()
    local handlers, render_callback, render_cancelled, preview
    local ctx, get_handlers = context({
        transport = {
            get_merge_request_diff = function(_, callback)
                callback('raw diff')
            end,
        },
        renderer = {
            render = function(_, callback)
                render_callback = callback
                return {
                    cancel = function()
                        render_cancelled = true
                    end,
                }
            end,
        },
    })
    browse.start(ctx)
    handlers = get_handlers()
    handlers.focus(mr, function(content)
        preview = content
    end)
    handlers.cancel()
    render_callback('late render', 'ansi')
    eq(render_cancelled, true)
    eq(preview, 'summary\n\nDiff\nLoading merge request diff…')
end

T['opens a valid GitLab web URL and rejects invalid URLs'] = function()
    local opened, notified
    local ctx, get_handlers = context({
        open_url = function(url)
            opened = url
        end,
        notify = function(message)
            notified = message
        end,
    })
    browse.start(ctx)
    local handlers = get_handlers()
    handlers.open_web(vim.tbl_extend('force', mr, {
        web_url = 'https://gitlab.example.com/group/project/-/merge_requests/2',
    }))
    eq(opened, 'https://gitlab.example.com/group/project/-/merge_requests/2')
    handlers.open_web(vim.tbl_extend('force', mr, { web_url = 'file:///tmp/unsafe' }))
    eq(notified, 'This merge request does not have a valid GitLab web URL.')
end

T['ignores a late merge request list after cancellation'] = function()
    local list_callback, opened
    local operation = browse.start({
        transport = {
            list_merge_requests = function(callback)
                list_callback = callback
                return { cancel = function() end }
            end,
        },
        renderer = {},
        picker = {
            pick_merge_request = function()
                opened = true
            end,
        },
        notify = function() end,
        open_url = function() end,
    })
    operation.cancel()
    list_callback({ mr })
    eq(opened, nil)
end

return T
