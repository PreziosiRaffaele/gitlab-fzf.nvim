local M = {}

local config = require('prview.config')
local overrides = {}
local options = config.resolve()
local active

local function notify(message, level)
    vim.notify(message, level or vim.log.levels.ERROR, { title = 'PRView' })
end

local function system_open(url, opener)
    local ok, command, err = pcall(opener or vim.ui.open, url)
    if not ok then
        return tostring(command)
    elseif not command then
        return tostring(err or 'no system URL handler is available')
    end
end

local function open_url(url)
    local err = system_open(url)
    if err then
        notify('Unable to open merge request in GitLab: ' .. err)
    end
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
    local renderer = overrides.renderer or require('prview.preview').new()
    local picker = overrides.picker or require('prview.picker.fzf').new(options.fzf_lua)
    active = require('prview.browse').start({
        transport = transport,
        renderer = renderer,
        picker = picker,
        notify = notify,
        open_url = overrides.open_url or open_url,
    })
end

function M.setup(opts)
    options = config.resolve(opts)
    overrides = opts and opts._test or {}
    pcall(vim.api.nvim_del_user_command, 'PRView')
    vim.api.nvim_create_user_command('PRView', M.open, {
        desc = 'Browse GitLab merge requests',
    })
end

M._system_open = system_open

return M
