local M = {}

local function default_runner(argv, opts, callback)
    local proc = vim.system(argv, opts, function(result)
        vim.schedule(function()
            callback(result)
        end)
    end)
    return {
        cancel = function()
            pcall(proc.kill, proc, 15)
        end,
    }
end

local function noop()
    return { cancel = function() end }
end

function M.new(opts)
    opts = opts or {}
    local runner = opts.runner or default_runner
    local executable = opts.executable or vim.fn.executable
    local renderer = {}

    function renderer.render(diff, callback)
        if type(diff) ~= 'string' or diff == '' then
            callback('This merge request has no textual changes.', 'text')
            return noop()
        end
        if executable('delta') ~= 1 then
            callback(diff, 'diff')
            return noop()
        end
        return runner({ 'delta', '--paging=never' }, { text = true, stdin = diff }, function(result)
            if result.code == 0 and type(result.stdout) == 'string' and result.stdout ~= '' then
                callback(result.stdout, 'ansi')
                return
            end
            callback(diff, 'diff')
        end)
    end

    return renderer
end

return M
