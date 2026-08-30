local M = {}

local function display_text(value, fallback)
    if type(value) ~= 'string' and type(value) ~= 'number' then
        return fallback
    end
    local result = tostring(value):gsub('%c', ' '):gsub('%s+', ' ')
    result = vim.trim(result)
    return result ~= '' and result or fallback
end

local function author_name(author)
    if type(author) == 'table' then
        local username = display_text(author.username)
        if username then
            return '@' .. username
        end
        local name = display_text(author.name)
        if name then
            return name
        end
    end
    return '?'
end

local month_names = {
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
}

local function is_leap_year(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

local function days_in_month(year, month)
    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if month == 2 and is_leap_year(year) then
        return 29
    end
    return days[month]
end

-- Days between 1970-01-01 and a Gregorian calendar date.
local function days_since_epoch(year, month, day)
    year = year - (month <= 2 and 1 or 0)
    local era = math.floor((year >= 0 and year or year - 399) / 400)
    local year_of_era = year - era * 400
    local shifted_month = month + (month > 2 and -3 or 9)
    local day_of_year = math.floor((153 * shifted_month + 2) / 5) + day - 1
    local day_of_era = year_of_era * 365 + math.floor(year_of_era / 4) - math.floor(year_of_era / 100) + day_of_year
    return era * 146097 + day_of_era - 719468
end

local function parse_updated_at(value)
    if type(value) ~= 'string' then
        return nil
    end
    local year, month, day, hour, minute, second, fraction, zone =
        value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)[Tt](%d%d):(%d%d):(%d%d)([%d%.]*)([%+%-Zz][%d:]*)$')
    if not zone then
        return nil
    end
    if fraction ~= '' and fraction:match('^%.%d+$') == nil then
        return nil
    end
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    hour, minute, second = tonumber(hour), tonumber(minute), tonumber(second)
    if
        month < 1
        or month > 12
        or day < 1
        or day > days_in_month(year, month)
        or hour > 23
        or minute > 59
        or second > 59
    then
        return nil
    end

    local offset = 0
    if zone:lower() ~= 'z' then
        local sign, offset_hour, offset_minute = zone:match('^([+-])(%d%d):?(%d%d)$')
        offset_hour, offset_minute = tonumber(offset_hour), tonumber(offset_minute)
        if not offset_hour or not offset_minute or offset_hour > 23 or offset_minute > 59 then
            return nil
        end
        offset = offset_hour * 3600 + offset_minute * 60
        if sign == '-' then
            offset = -offset
        end
    end
    return days_since_epoch(year, month, day) * 86400 + hour * 3600 + minute * 60 + second - offset, year, month, day
end

local function relative_time(seconds, unit)
    return seconds .. ' ' .. unit .. (seconds == 1 and '' or 's') .. ' ago'
end

function M.friendly_updated_at(value, now)
    local timestamp, year, month, day = parse_updated_at(value)
    if not timestamp then
        return 'unknown'
    end
    local age = math.max(0, (now or os.time()) - timestamp)
    if age < 60 then
        return 'just now'
    elseif age < 3600 then
        return relative_time(math.floor(age / 60), 'minute')
    elseif age < 86400 then
        return relative_time(math.floor(age / 3600), 'hour')
    elseif age < 7 * 86400 then
        return relative_time(math.floor(age / 86400), 'day')
    end
    return string.format('%d %s %d', day, month_names[month], year)
end

local ansi = {
    reset = '\27[0m',
    yellow = '\27[0;33m',
    green = '\27[0;32m',
    blue = '\27[0;34m',
}

local function paint(color, text)
    return ansi[color] .. text .. ansi.reset
end

function M.merge_request(mr)
    return string.format(
        '%s %s %s %s',
        paint('yellow', '!' .. display_text(mr.iid, '?')),
        paint('green', '(' .. M.friendly_updated_at(mr.updated_at) .. ')'),
        display_text(mr.title, '(untitled)'),
        paint('blue', '<' .. author_name(mr.author) .. '>')
    )
end

function M.merge_request_header()
    return string.format(
        '%s %s %s %s',
        paint('yellow', 'MR Number'),
        paint('green', '(Last Updated Time)'),
        'Title',
        paint('blue', '<Author>')
    )
end

return M
