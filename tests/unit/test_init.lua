local gitlab_fzf = require('gitlab-fzf')
local eq = MiniTest.expect.equality
local T = MiniTest.new_set()

T['registers the renamed command idempotently'] = function()
    gitlab_fzf.setup()
    gitlab_fzf.setup()

    local command = vim.api.nvim_get_commands({})['GitLabFzf']
    eq(type(command), 'table')
    eq(type(command.callback), 'function')
    eq(command.definition, 'Browse GitLab merge requests')
end

T['opens URLs with Neovim system handlers and reports adapter errors'] = function()
    local opened
    local err = gitlab_fzf._system_open('https://gitlab.example.com/group/project/-/merge_requests/2', function(url)
        opened = url
        return {}
    end)
    eq(err, nil)
    eq(opened, 'https://gitlab.example.com/group/project/-/merge_requests/2')

    err = gitlab_fzf._system_open('https://gitlab.example.com', function()
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
    gitlab_fzf.setup({
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
    gitlab_fzf.open()
    vim.fn.executable = previous_executable
    package.loaded['fzf-lua'] = previous_fzf
    eq(checked, { 'glab' })
    eq(picked, true)
end

T['passes setup fzf-lua settings to the picker'] = function()
    local received, picked
    local previous_picker = package.loaded['gitlab-fzf.picker.fzf']
    package.loaded['gitlab-fzf.picker.fzf'] = {
        new = function(opts)
            received = opts
            return {
                pick_merge_request = function()
                    picked = true
                end,
            }
        end,
    }
    gitlab_fzf.setup({
        fzf_lua = {
            prompt = 'Reviews> ',
            winopts = { fullscreen = false },
        },
        _test = {
            skip_dependency_check = true,
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
        },
    })
    gitlab_fzf.open()
    package.loaded['gitlab-fzf.picker.fzf'] = previous_picker

    eq(received, {
        prompt = 'Reviews> ',
        winopts = { fullscreen = false },
    })
    eq(picked, true)
end

return T
