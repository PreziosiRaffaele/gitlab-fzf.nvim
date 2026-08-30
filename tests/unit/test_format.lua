local format = require('prview.format')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local function merge_request(overrides)
    return vim.tbl_deep_extend('force', {
        iid = 7,
        title = 'Full diff preview',
        draft = true,
        author = { username = 'alice' },
        source_branch = 'feature',
        target_branch = 'main',
        updated_at = '2026-08-30T10:00:00Z',
    }, overrides or {})
end

T['formats native tab-delimited picker fields'] = function()
    eq(format.merge_request(merge_request()), '!7\t@alice\tFull diff preview')
    eq(format.merge_request(merge_request({ draft = false, title = 'Ready' })), '!7\t@alice\tReady')
    eq(
        format.merge_request(merge_request({ author = { username = vim.NIL, name = 'Alice' } })),
        '!7\tAlice\tFull diff preview'
    )
    eq(format.merge_request(merge_request({ author = vim.NIL })), '!7\t?\tFull diff preview')
end

T['keeps long and multibyte titles without manual styling'] = function()
    local title = '界面 keeps this complete even when it is much longer than one tab stop'
    local entry = format.merge_request(merge_request({ title = title }))
    eq(entry, '!7\t@alice\t' .. title)
    eq(entry:find('\27', 1, true), nil)
end

T['sanitizes remote values before creating tab fields'] = function()
    local entry = format.merge_request(merge_request({
        title = 'Fix\tline\nbreak\27[31m',
        author = { username = 'ali\nce' },
    }))
    local _, tab_count = entry:gsub('\t', '')
    eq(tab_count, 2)
    eq(entry, '!7\t@ali ce\tFix line break [31m')
end

T['formats complete metadata for the diff preview'] = function()
    eq(
        format.preview_header(merge_request()),
        'Merge request !7 · DRAFT · Full diff preview\n'
            .. 'Author @alice │ feature → main │ Updated 2026-08-30 10:00:00 UTC'
    )
end

return T
