local picker = require('prview.picker.fzf')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

local function capture_picker(handlers, opts)
    local captured
    local previous = package.loaded['fzf-lua']
    package.loaded['fzf-lua'] = {
        fzf_exec = function(entries, opts)
            captured = opts
            captured._input = entries
        end,
    }
    picker.new(opts).pick_merge_request({ { iid = 1, title = 'One' }, { iid = 2, title = 'Two' } }, handlers)
    package.loaded['fzf-lua'] = previous
    return captured
end

T['forwards configured options while retaining PRView behavior'] = function()
    local cancelled, closed = false, false
    local custom_action = function() end
    local configured = {
        prompt = 'Reviews> ',
        fzf_opts = { ['--ansi'] = false, ['--header-lines'] = 3, ['--info'] = 'inline', ['--tabstop'] = 4 },
        actions = { ['ctrl-x'] = custom_action },
        previewer = 'configured previewer',
        winopts = {
            fullscreen = false,
            preview = { layout = 'vertical' },
            on_close = function()
                closed = true
            end,
        },
    }
    local captured = capture_picker({
        format = function(value)
            return value.title
        end,
        focus = function() end,
        cancel = function()
            cancelled = true
        end,
    }, configured)

    eq(captured.prompt, 'Reviews> ')
    eq(captured.winopts.fullscreen, false)
    eq(captured.winopts.preview, { layout = 'vertical' })
    eq(captured.fzf_opts['--info'], 'inline')
    eq(captured.fzf_opts['--ansi'], false)
    eq(captured.fzf_opts['--delimiter'], '\t')
    eq(captured.fzf_opts['--header-lines'], 1)
    eq(captured.fzf_opts['--tabstop'], 4)
    eq(captured.fzf_opts['--with-nth'], '2..')
    eq(captured.actions['ctrl-x'], custom_action)
    eq(type(captured.actions.default.fn), 'function')
    eq(type(captured.actions['ctrl-o'].fn), 'function')
    eq(type(captured.previewer), 'table')

    captured.winopts.on_close()
    eq(cancelled, true)
    eq(closed, true)
    eq(configured.previewer, 'configured previewer')
    eq(configured.winopts.on_close ~= captured.winopts.on_close, true)
end

T['passes item rows with a column header and retains hidden selection indexes'] = function()
    local captured = capture_picker({
        focus = function() end,
    })

    eq(captured.fzf_opts['--tabstop'], 4)
    eq(#captured._input, 2)
    eq(captured._input[1]:match('^1\t!1\t%?\tOne\t'), '1\t!1\t?\tOne\t')
    eq(captured._input[2]:match('^2\t!2\t%?\tTwo\t'), '2\t!2\t?\tTwo\t')
    eq(captured.fzf_opts['--header'], 'MR\tAuthor\tTitle\tUpdated')
    eq(captured.fzf_opts['--header-lines'], 1)
end

T['opens fullscreen and keeps enter on the single picker'] = function()
    local cancelled
    local captured = capture_picker({
        format = function(value)
            return value.title
        end,
        focus = function() end,
        cancel = function()
            cancelled = true
        end,
    }, require('prview.config').resolve().fzf_lua)
    eq(captured.winopts.fullscreen, true)
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
    picker.new().pick_merge_request(items, {
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
