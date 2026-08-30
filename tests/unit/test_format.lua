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
    eq(
        format.merge_request(merge_request()):match('^!7\t@alice\tFull diff preview\t'),
        '!7\t@alice\tFull diff preview\t'
    )
    eq(
        format.merge_request(merge_request({ draft = false, title = 'Ready' })):match('^!7\t@alice\tReady\t'),
        '!7\t@alice\tReady\t'
    )
    eq(
        format
            .merge_request(merge_request({ author = { username = vim.NIL, name = 'Alice' } }))
            :match('^!7\tAlice\tFull diff preview\t'),
        '!7\tAlice\tFull diff preview\t'
    )
    eq(
        format.merge_request(merge_request({ author = vim.NIL })):match('^!7\t%?\tFull diff preview\t'),
        '!7\t?\tFull diff preview\t'
    )
end

T['keeps long and multibyte titles without manual styling'] = function()
    local title = '界面 keeps this complete even when it is much longer than one tab stop'
    local entry = format.merge_request(merge_request({ title = title }))
    eq(entry:match('^!7\t@alice\t' .. title .. '\t'), '!7\t@alice\t' .. title .. '\t')
    eq(entry:find('\27', 1, true), nil)
end

T['sanitizes remote values before creating tab fields'] = function()
    local entry = format.merge_request(merge_request({
        title = 'Fix\tline\nbreak\27[31m',
        author = { username = 'ali\nce' },
    }))
    local _, tab_count = entry:gsub('\t', '')
    eq(tab_count, 3)
    eq(entry:match('^!7\t@ali ce\tFix line break %[31m\t'), '!7\t@ali ce\tFix line break [31m\t')
end

T['formats the picker column header'] = function()
    eq(format.merge_request_header(), 'MR\tAuthor\tTitle\tUpdated')
end

T['formats friendly update times from GitLab timestamps'] = function()
    local now = 1788091445
    eq(format.friendly_updated_at('2026-08-30T12:03:00Z', now), '1 minute ago')
    eq(format.friendly_updated_at('2026-08-30T12:00:00Z', now), '4 minutes ago')
    eq(format.friendly_updated_at('2026-08-30T10:00:00Z', now), '2 hours ago')
    eq(format.friendly_updated_at('2026-08-27T12:04:05Z', now), '3 days ago')
    eq(format.friendly_updated_at('2026-08-20T12:04:05Z', now), '20 Aug 2026')
end

T['accepts offsets and handles unusable update times'] = function()
    local now = 1788091445
    eq(format.friendly_updated_at('2026-08-30T12:00:00+02:00', now), '2 hours ago')
    eq(format.friendly_updated_at('2026-08-30T13:05:00Z', now), 'just now')
    eq(format.friendly_updated_at('not a timestamp', now), 'unknown')
    eq(format.friendly_updated_at('2026-08-30T12:00:00+', now), 'unknown')
    eq(format.friendly_updated_at(nil, now), 'unknown')
end

return T
