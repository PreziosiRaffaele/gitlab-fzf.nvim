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

local function strip_ansi(text)
    return (text:gsub('\27%[[%d;]*m', ''))
end

local function paint(code, text)
    return '\27[' .. code .. 'm' .. text .. '\27[0m'
end

local function entry(overrides)
    local mr = merge_request(overrides)
    return format.merge_request(mr), format.friendly_updated_at(mr.updated_at)
end

T['formats picker fields as IID, updated time, title, and author'] = function()
    local formatted, updated = entry()
    eq(strip_ansi(formatted), '!7 (' .. updated .. ') Full diff preview <@alice>')
    formatted, updated = entry({ draft = false, title = 'Ready' })
    eq(strip_ansi(formatted), '!7 (' .. updated .. ') Ready <@alice>')
    formatted, updated = entry({ author = { username = vim.NIL, name = 'Alice' } })
    eq(strip_ansi(formatted), '!7 (' .. updated .. ') Full diff preview <Alice>')
    formatted, updated = entry({ author = vim.NIL })
    eq(strip_ansi(formatted), '!7 (' .. updated .. ') Full diff preview <?>')
end

T['colors IID, update time, and author like git commits'] = function()
    local formatted, updated = entry()
    eq(
        formatted,
        paint('0;33', '!7')
            .. ' '
            .. paint('0;32', '(' .. updated .. ')')
            .. ' Full diff preview '
            .. paint('0;34', '<@alice>')
    )
end

T['keeps long and multibyte titles without styling the title'] = function()
    local title = '界面 keeps this complete even when it is much longer than one tab stop'
    local formatted, updated = entry({ title = title })
    eq(strip_ansi(formatted), '!7 (' .. updated .. ') ' .. title .. ' <@alice>')
    eq(formatted:find(title, 1, true) ~= nil, true)
end

T['sanitizes remote values before creating picker fields'] = function()
    local formatted, updated = entry({
        title = 'Fix\tline\nbreak\27[31m',
        author = { username = 'ali\nce' },
    })
    local _, tab_count = formatted:gsub('\t', '')
    eq(tab_count, 0)
    eq(strip_ansi(formatted), '!7 (' .. updated .. ') Fix line break [31m <@ali ce>')
end

T['formats the picker header'] = function()
    eq(strip_ansi(format.merge_request_header()), 'MR Number (Last Updated Time) Title <Author>')
    eq(
        format.merge_request_header(),
        paint('0;33', 'MR Number')
            .. ' '
            .. paint('0;32', '(Last Updated Time)')
            .. ' Title '
            .. paint('0;34', '<Author>')
    )
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
