# gitlab-fzf.nvim

Browse open GitLab merge requests and inspect each full diff in a single
fzf-lua picker. Open an MR in GitLab or check out its source branch directly
from the picker.

## Requirements

- Neovim 0.10 or newer
- [`glab`](https://gitlab.com/gitlab-org/cli) 1.80.0 or newer (required)
- [`fzf-lua`](https://github.com/ibhagwan/fzf-lua) (required)
- [`delta`](https://github.com/dandavison/delta) (optional, for colored diffs)

Authenticate for the repository's GitLab host with `glab auth login`, or expose
`GITLAB_TOKEN` to Neovim. Tokens are handled only by `glab`.

## Installation

With lazy.nvim:

```lua
{
  'PreziosiRaffaele/gitlab-fzf.nvim',
  dependencies = { 'ibhagwan/fzf-lua' },
  opts = {},
}
```

## Configuration

The picker opens fullscreen by default. Pass per-picker fzf-lua options through
`fzf_lua`; nested values override GitLab Fzf's defaults:

```lua
require('gitlab-fzf').setup({
  fzf_lua = {
    prompt = 'Reviews> ',
    winopts = {
      fullscreen = false,
      width = 0.9,
    },
  },
})
```

## Usage

Run `:GitLabFzf` and highlight an open merge request to load its complete,
scrollable GitLab diff in the preview.

The preview shows the merge request title, branches, status, reviewers, labels,
and first description paragraph, followed by changed-file counts grouped by
top-level repository area and then the diff.

Press `Ctrl-O` to open the highlighted merge request in the browser without
closing the picker. Press `Ctrl-B` to close the picker and check out the
highlighted merge request's source branch.

## License

MIT. See [LICENSE](LICENSE).
