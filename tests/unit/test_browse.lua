local browse = require('prview.browse')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local mr = {
    project_id = 1,
    iid = 2,
    title = 'MR',
    source_branch = 'feature',
    target_branch = 'main',
}
local file = {
    status = 'M',
    old_path = 'a.lua',
    new_path = 'a.lua',
    patch = '@@ -1 +1 @@\n-a\n+b',
    additions = 1,
    deletions = 1,
}

T['loads preview lazily, caches it, and opens files'] = function()
    local handlers, file_items, changed_calls = nil, nil, 0
    browse.start({
        transport = {
            list_merge_requests = function(callback)
                callback({ mr })
            end,
            list_changed_files = function(_, callback)
                changed_calls = changed_calls + 1
                callback({ file })
            end,
        },
        picker = {
            pick_merge_request = function(_, value)
                handlers = value
            end,
            pick_changed_file = function(items)
                file_items = items
            end,
        },
        notify = function() end,
    })
    local summary
    handlers.focus(mr, function(value)
        summary = value
    end)
    handlers.select(mr)
    eq(summary:find('1 files', 1, true) ~= nil, true)
    eq(changed_calls, 1)
    eq(file_items, { file })
end

T['ignores a late callback after cancellation'] = function()
    local list_callback, opened
    local operation = browse.start({
        transport = {
            list_merge_requests = function(callback)
                list_callback = callback
                return { cancel = function() end }
            end,
        },
        picker = {
            pick_merge_request = function()
                opened = true
            end,
        },
        notify = function() end,
    })
    operation.cancel()
    list_callback({ mr })
    eq(opened, nil)
end

return T
