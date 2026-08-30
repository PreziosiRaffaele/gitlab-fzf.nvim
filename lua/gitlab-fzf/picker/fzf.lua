local format = require('gitlab-fzf.format')

local M = {}

local function entries(items, formatter)
    local result = {}
    for index, item in ipairs(items) do
        result[index] = string.format('%d\t%s', index, formatter(item))
    end
    return result
end

local function selected(items, lines)
    local index = tonumber(type(lines) == 'table' and lines[1] and lines[1]:match('^(%d+)\t'))
    return index and items[index] or nil
end

local function memory_previewer(items, populate)
    return {
        _ctor = function()
            local base = require('fzf-lua.previewer.builtin').base
            local custom = base:extend()
            function custom:populate_preview_buf(selection)
                local item = selected(items, { selection })
                local buffer = self:get_tmp_buffer()
                self:set_preview_buf(buffer, true)
                local function update(content, syntax)
                    if not vim.api.nvim_buf_is_valid(buffer) then
                        return
                    end
                    vim.bo[buffer].modifiable = true
                    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, vim.split(content or '', '\n', { plain = true }))
                    if syntax == 'ansi' then
                        vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {})
                        local channel = vim.api.nvim_open_term(buffer, {})
                        vim.api.nvim_chan_send(channel, content)
                    else
                        vim.bo[buffer].filetype = syntax or 'text'
                    end
                    vim.bo[buffer].modifiable = false
                end
                if item then
                    populate(item, update)
                end
            end
            return custom
        end,
    }
end

local function pick_merge_request(items, handlers, configured)
    local fzf = require('fzf-lua')
    local configured_on_close = configured.winopts and configured.winopts.on_close
    local opts = vim.tbl_deep_extend('force', {
        prompt = 'Merge requests> ',
    }, vim.deepcopy(configured))
    local required_fzf_opts = {
        ['--ansi'] = true,
        ['--delimiter'] = '\t',
        ['--header'] = format.merge_request_header(),
        ['--with-nth'] = '2..',
    }
    opts.fzf_opts = vim.tbl_deep_extend('force', {}, opts.fzf_opts or {}, required_fzf_opts)
    if opts.fzf_opts['--tabstop'] == nil then
        opts.fzf_opts['--tabstop'] = 4
    end
    opts.actions = vim.tbl_deep_extend('force', {}, opts.actions or {}, {
        ['default'] = { fn = function() end, exec_silent = true },
        ['ctrl-o'] = {
            fn = function(lines)
                local item = selected(items, lines)
                if item and handlers.open_web then
                    handlers.open_web(item)
                end
            end,
            exec_silent = true,
            header = 'open in GitLab',
        },
        ['ctrl-b'] = {
            fn = function(lines)
                local item = selected(items, lines)
                if item and handlers.checkout then
                    handlers.checkout(item)
                end
            end,
            header = 'check out source branch',
        },
    })
    opts.previewer = memory_previewer(items, function(item, update)
        handlers.focus(item, update)
    end)
    opts.winopts = opts.winopts or {}
    opts.winopts.on_close = function(...)
        if handlers.cancel then
            handlers.cancel()
        end
        if configured_on_close then
            configured_on_close(...)
        end
    end
    fzf.fzf_exec(entries(items, handlers.format or format.merge_request), opts)
end

function M.new(opts)
    opts = opts or {}
    return {
        pick_merge_request = function(items, handlers)
            pick_merge_request(items, handlers, opts)
        end,
    }
end

return M
