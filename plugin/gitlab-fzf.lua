if vim.g.loaded_gitlab_fzf == 1 then
    return
end

vim.g.loaded_gitlab_fzf = 1
require('gitlab-fzf').setup()
