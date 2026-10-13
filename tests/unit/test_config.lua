local config = require('gitlab-fzf.config')
local eq = MiniTest.expect.equality
local expect_error = MiniTest.expect.error
local T = MiniTest.new_set()

T['defaults the picker to fullscreen'] = function()
    eq(config.resolve(), {
        fzf_lua = {
            winopts = {
                fullscreen = true,
            },
            fzf_opts = {
                ['--exact'] = true,
                ['--no-info'] = true,
                ['--no-sort'] = true,
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
        fzf_opts = { ['--exact'] = false },
        prompt = 'Reviews> ',
    }
    local resolved = config.resolve({ fzf_lua = supplied })
    eq(resolved, {
        fzf_lua = {
            winopts = {
                fullscreen = false,
                preview = { layout = 'vertical' },
            },
            fzf_opts = {
                ['--exact'] = false,
                ['--no-info'] = true,
                ['--no-sort'] = true,
            },
            prompt = 'Reviews> ',
        },
    })
    eq(supplied, {
        winopts = {
            fullscreen = false,
            preview = { layout = 'vertical' },
        },
        fzf_opts = { ['--exact'] = false },
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
