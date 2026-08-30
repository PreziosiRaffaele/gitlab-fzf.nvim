local config = require('prview.config')
local eq = MiniTest.expect.equality
local expect_error = MiniTest.expect.error
local T = MiniTest.new_set()

T['defaults the picker to fullscreen'] = function()
    eq(config.resolve(), {
        fzf_lua = {
            winopts = {
                fullscreen = true,
            },
        },
    })
end

T['deeply merges fzf-lua settings without mutating input'] = function()
    local supplied = {
        winopts = {
            fullscreen = false,
            preview = { layout = 'vertical' },
        },
        prompt = 'Reviews> ',
    }
    local resolved = config.resolve({ fzf_lua = supplied })
    eq(resolved, {
        fzf_lua = {
            winopts = {
                fullscreen = false,
                preview = { layout = 'vertical' },
            },
            prompt = 'Reviews> ',
        },
    })
    eq(supplied, {
        winopts = {
            fullscreen = false,
            preview = { layout = 'vertical' },
        },
        prompt = 'Reviews> ',
    })
end

T['rejects invalid and unknown options'] = function()
    expect_error(function()
        config.resolve('fullscreen')
    end, 'options must be a table')
    expect_error(function()
        config.resolve({ fzf_lua = true })
    end, '`fzf_lua` must be a table')
    expect_error(function()
        config.resolve({ fzf_lua = { winopts = { fullscreen = 'yes' } } })
    end, '`fzf_lua.winopts.fullscreen` must be a boolean')
    expect_error(function()
        config.resolve({ picker = {} })
    end, 'unknown option `picker`')
end

return T
