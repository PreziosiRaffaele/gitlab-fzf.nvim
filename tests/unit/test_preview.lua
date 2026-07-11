local preview = require('prview.preview')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T['builds added patch with dev null'] = function()
    local patch = preview.patch({ status = 'A', old_path = 'x', new_path = 'x', patch = '@@ -0,0 +1 @@\n+x' })
    eq(patch, 'diff --git a/x b/x\n--- /dev/null\n+++ b/x\n@@ -0,0 +1 @@\n+x')
end

T['describes unavailable patch'] = function()
    local patch, message = preview.patch({ binary = true })
    eq(patch, nil)
    eq(message, 'Binary change; no textual patch is available.')
end

T['falls back when delta fails'] = function()
    local result
    preview.render(
        { status = 'M', old_path = 'x', new_path = 'x', patch = '@@ -1 +1 @@\n-a\n+b' },
        function(_, _, callback)
            callback({ code = 1, stderr = 'no delta' })
        end,
        function(content, syntax)
            result = { content, syntax }
        end
    )
    eq(result[2], 'diff')
    eq(result[1]:find('diff --git a/x b/x', 1, true) ~= nil, true)
end

return T
