local preview = require('prview.preview')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local diff = 'diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -1 +1 @@\n-a\n+b\n'

T["uses Delta's full structural formatting"] = function()
    local argv, opts, result
    local renderer = preview.new({
        executable = function(name)
            eq(name, 'delta')
            return 1
        end,
        runner = function(value, options, callback)
            argv, opts = value, options
            callback({ code = 0, stdout = '\27[32m+b\27[0m\n' })
        end,
    })
    renderer.render(diff, function(content, syntax)
        result = { content, syntax }
    end)
    eq(argv, { 'delta', '--paging=never' })
    eq(opts, { text = true, stdin = diff })
    eq(result, { '\27[32m+b\27[0m\n', 'ansi' })
end

T['uses diff syntax when delta is unavailable'] = function()
    local ran, result
    local renderer = preview.new({
        executable = function()
            return 0
        end,
        runner = function()
            ran = true
        end,
    })
    renderer.render(diff, function(content, syntax)
        result = { content, syntax }
    end)
    eq(ran, nil)
    eq(result, { diff, 'diff' })
end

T['falls back to the raw diff when delta fails'] = function()
    local result
    local renderer = preview.new({
        executable = function()
            return 1
        end,
        runner = function(_, _, callback)
            callback({ code = 1, stderr = 'delta failed' })
        end,
    })
    renderer.render(diff, function(content, syntax)
        result = { content, syntax }
    end)
    eq(result, { diff, 'diff' })
end

T['describes an empty raw diff'] = function()
    local result
    preview
        .new({
            executable = function()
                return 0
            end,
        })
        .render('', function(content, syntax)
            result = { content, syntax }
        end)
    eq(result, { 'This merge request has no textual changes.', 'text' })
end

return T
