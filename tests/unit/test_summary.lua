local summary = require('gitlab-fzf.summary')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T['renders merge request context and changed areas before the diff'] = function()
    local mr = {
        iid = 7,
        title = 'Preview\tsummary',
        description = '\nFirst line\ncontinues here.\n\nIgnored paragraph.',
        author = { username = 'alice' },
        reviewers = { { username = 'bob' }, { name = 'Sue' } },
        labels = { 'enhancement', { name = 'user\ninterface' } },
        source_branch = 'feature',
        target_branch = 'main',
        updated_at = '2026-08-30T10:00:00Z',
        detailed_merge_status = 'ci_still_running',
    }
    local diff = table.concat({
        'diff --git a/README.md b/README.md',
        'diff --git a/docs/spec.md b/docs/spec.md',
        'diff --git a/lua/one.lua b/lua/one.lua',
        'diff --git "a/lua/space name.lua" "b/lua/space name.lua"',
        'diff --git a/tests/one.lua b/tests/one.lua',
        'diff --git a/tests/two.lua b/tests/two.lua',
    }, '\n')

    eq(
        summary.render(mr, diff, { now = 1788091445 }),
        table.concat({
            '!7  Preview summary',
            '@alice · feature → main · ci still running · updated 2 hours ago',
            'Reviewers: @bob, Sue',
            'Labels: enhancement, user interface',
            'Summary: First line continues here.',
            '',
            'Changed areas · 6 files',
            '  [root] · 1 file',
            '  docs · 1 file',
            '  lua · 2 files',
            '  tests · 2 files',
        }, '\n')
    )
end

T['uses draft state and omits absent optional sections'] = function()
    eq(
        summary.render({ iid = 2, title = 'Draft', draft = true, source_branch = 'work', target_branch = 'main' }),
        table.concat({
            '!2  Draft',
            '? · work → main · draft · updated unknown',
        }, '\n')
    )
end

T['extracts unique renamed and Git-quoted paths'] = function()
    local diff = table.concat({
        'diff --git a/old/name.lua b/new/name.lua',
        'diff --git a/old/name.lua b/new/name.lua',
        'diff --git "a/docs/na\\303\\257ve.md" "b/docs/na\\303\\257ve.md"',
        'diff --git "a/root file" "b/root file"',
    }, '\n')
    local areas, count = summary._changed_areas(diff)
    eq(count, 3)
    eq(areas, {
        { name = '[root]', count = 1 },
        { name = 'docs', count = 1 },
        { name = 'new', count = 1 },
    })
end

T['truncates description excerpts by characters'] = function()
    local excerpt = summary._description_excerpt(string.rep('界', 241) .. '\n\nignored')
    eq(vim.fn.strchars(excerpt), 240)
    eq(excerpt:sub(-3), '…')
end

return T
