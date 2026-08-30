local prview = require('prview')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T['opens URLs with Neovim system handlers and reports adapter errors'] = function()
    local opened
    local err = prview._system_open('https://gitlab.example.com/group/project/-/merge_requests/2', function(url)
        opened = url
        return {}
    end)
    eq(err, nil)
    eq(opened, 'https://gitlab.example.com/group/project/-/merge_requests/2')

    err = prview._system_open('https://gitlab.example.com', function()
        return nil, 'no handler'
    end)
    eq(err, 'no handler')
end

T['does not require the git executable'] = function()
    local checked, picked = {}, false
    local previous_executable = vim.fn.executable
    local previous_fzf = package.loaded['fzf-lua']
    vim.fn.executable = function(name)
        checked[#checked + 1] = name
        return name == 'glab' and 1 or 0
    end
    package.loaded['fzf-lua'] = {}
    prview.setup({
        _test = {
            transport = {
                list_merge_requests = function(callback)
                    callback({
                        {
                            project_id = 1,
                            iid = 2,
                            title = 'MR',
                            source_branch = 'feature',
                            target_branch = 'main',
                        },
                    })
                end,
            },
            renderer = {},
            picker = {
                pick_merge_request = function()
                    picked = true
                end,
            },
        },
    })
    prview.open()
    vim.fn.executable = previous_executable
    package.loaded['fzf-lua'] = previous_fzf
    eq(checked, { 'glab' })
    eq(picked, true)
end

return T
