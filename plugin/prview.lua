if vim.g.loaded_prview == 1 then
    return
end

vim.g.loaded_prview = 1
require('prview').setup()
