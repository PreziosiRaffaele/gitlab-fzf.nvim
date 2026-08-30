# gitlab-fzf.nvim

Browse open GitLab merge requests and inspect each full diff in a single
fzf-lua picker. GitLab Fzf does not change local repository or GitLab state.

## Requirements

- Neovim 0.10 or newer
- [`glab`](https://gitlab.com/gitlab-org/cli) (required)
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
scrollable GitLab diff in the preview. Each entry shows the merge request IID,
relative latest-update time, title, and author as
`!IID (updated) title <@author>`, colored like fzf-lua git commits, under the
`MR Number (Last Updated Time) Title <Author>` header. The preview shows the
diff. Delta formats and colors the diff when installed; raw diff syntax is the
fallback. Press `Ctrl-O` to open the highlighted merge request in GitLab
without closing the picker. No external process or dependency check runs
during startup.

## Development

Run `make check`.
