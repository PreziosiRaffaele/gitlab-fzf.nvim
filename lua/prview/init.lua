local M = {}

local overrides = {}
local active

local function notify(message, level)
    vim.notify(message, level or vim.log.levels.ERROR, { title = 'PRView' })
end

local function dependency_error()
    if vim.fn.executable('glab') ~= 1 then
        return 'PRView requires `glab`. Install it, then authenticate with `glab auth login` or GITLAB_TOKEN.'
    end
    local ok = pcall(require, 'fzf-lua')
    if not ok then
        return 'PRView requires `fzf-lua`. Install and load fzf-lua before running :PRView.'
    end
end

function M.open()
    if active and active.cancel then
        active.cancel()
        active = nil
    end
    local err = dependency_error()
    if err and not overrides.skip_dependency_check then
        notify(err)
        return
    end

    local transport = overrides.transport or require('prview.gitlab').new()
    local picker = overrides.picker or require('prview.picker.fzf')
    active = require('prview.browse').start({ transport = transport, picker = picker, notify = notify })
end

function M.setup(opts)
    -- Options are intentionally private test seams, not user configuration.
    overrides = opts and opts._test or {}
    pcall(vim.api.nvim_del_user_command, 'PRView')
    vim.api.nvim_create_user_command('PRView', M.open, {
        desc = 'Browse GitLab merge requests',
    })
end

return M
