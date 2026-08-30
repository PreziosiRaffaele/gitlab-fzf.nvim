local function plugin_root()
    local this = debug.getinfo(1, 'S').source:sub(2)
    return vim.fn.fnamemodify(this, ':p:h:h')
end

local root = plugin_root()
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(root .. '/deps/mini.nvim')
vim.opt.rtp:prepend(root .. '/deps/fzf-lua')
vim.o.swapfile = false
vim.o.shadafile = 'NONE'

require('mini.test').setup()
