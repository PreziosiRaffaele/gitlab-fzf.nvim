local picker = require('prview.picker.fzf')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local function capture_picker(handlers)
    local captured
    local previous = package.loaded['fzf-lua']
    package.loaded['fzf-lua'] = {
        fzf_exec = function(_, opts)
            captured = opts
        end,
    }
    picker.pick_merge_request({ { title = 'One' }, { title = 'Two' } }, handlers)
    package.loaded['fzf-lua'] = previous
    return captured
end

T['keeps enter on the single picker without navigating'] = function()
    local cancelled
    local captured = capture_picker({
        format = function(value)
            return value.title
        end,
        focus = function() end,
        cancel = function()
            cancelled = true
        end,
    })
    eq(type(captured.actions.default.fn), 'function')
    eq(captured.actions.default.exec_silent, true)
    captured.winopts.on_close()
    eq(cancelled, true)
end

T['opens the highlighted merge request in GitLab without closing fzf'] = function()
    local opened
    local items = { { title = 'One' }, { title = 'Two' } }
    local captured
    local previous = package.loaded['fzf-lua']
    package.loaded['fzf-lua'] = {
        fzf_exec = function(_, opts)
            captured = opts
        end,
    }
    picker.pick_merge_request(items, {
        format = function(value)
            return value.title
        end,
        focus = function() end,
        open_web = function(value)
            opened = value
        end,
    })
    package.loaded['fzf-lua'] = previous

    local action = captured.actions['ctrl-o']
    eq(action.exec_silent, true)
    eq(action.header, 'open in GitLab')
    action.fn({ '2\tTwo' })
    eq(opened, items[2])
end

return T
