local format = require('prview.format')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T['formats a merge request picker entry'] = function()
    eq(
        format.merge_request({
            iid = 7,
            title = 'Full diff preview',
            draft = true,
            author = { username = 'alice' },
            source_branch = 'feature',
            target_branch = 'main',
            updated_at = '2026-08-30T10:00:00Z',
        }),
        '!7  [Draft] Full diff preview  @alice  feature -> main  2026-08-30T10:00:00Z'
    )
end

return T
