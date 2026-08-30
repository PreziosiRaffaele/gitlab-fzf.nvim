local M = {}

local defaults = {
    fzf_lua = {
        winopts = {
            fullscreen = true,
        },
    },
}

local function invalid(message)
    error('PRView setup: ' .. message, 3)
end

local function validate_fzf_lua(opts)
    if opts == nil then
        return
    elseif type(opts) ~= 'table' then
        invalid('`fzf_lua` must be a table')
    end

    if opts.winopts ~= nil and type(opts.winopts) ~= 'table' then
        invalid('`fzf_lua.winopts` must be a table')
    elseif opts.winopts then
        if opts.winopts.fullscreen ~= nil and type(opts.winopts.fullscreen) ~= 'boolean' then
            invalid('`fzf_lua.winopts.fullscreen` must be a boolean')
        end
        if opts.winopts.on_close ~= nil and type(opts.winopts.on_close) ~= 'function' then
            invalid('`fzf_lua.winopts.on_close` must be a function')
        end
    end

    for _, name in ipairs({ 'actions', 'fzf_opts' }) do
        if opts[name] ~= nil and type(opts[name]) ~= 'table' then
            invalid(string.format('`fzf_lua.%s` must be a table', name))
        end
    end
end

function M.resolve(opts)
    if opts == nil then
        opts = {}
    elseif type(opts) ~= 'table' then
        invalid('options must be a table')
    end

    for name in pairs(opts) do
        if name ~= 'fzf_lua' and name ~= '_test' then
            invalid(string.format('unknown option `%s`', name))
        end
    end
    if opts._test ~= nil and type(opts._test) ~= 'table' then
        invalid('`_test` must be a table')
    end
    validate_fzf_lua(opts.fzf_lua)

    return vim.tbl_deep_extend('force', {}, defaults, {
        fzf_lua = opts.fzf_lua or {},
    })
end

return M
