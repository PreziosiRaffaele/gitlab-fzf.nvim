# prview.nvim

Browse open GitLab merge requests and preview their changed-file patches from
Neovim. PRView is read-only: it never checks out branches or changes repository
state.

## Requirements

- Neovim 0.10 or newer
- [`glab`](https://gitlab.com/gitlab-org/cli) (required)
- [`fzf-lua`](https://github.com/ibhagwan/fzf-lua) (required)
- [`delta`](https://github.com/dandavison/delta) (optional, for colored patches)

Authenticate for the repository's GitLab host with `glab auth login`, or expose
`GITLAB_TOKEN` to Neovim. Tokens are handled only by `glab`.

## Installation

With lazy.nvim:

```lua
{
  'prview.nvim',
  dependencies = { 'ibhagwan/fzf-lua' },
  opts = {},
}
```

## Usage

Run `:PRView`, highlight an open merge request to load its changed-file summary,
then select it to browse and preview individual patches. No external process or
dependency check runs during startup.

## Development

Run `make check`.
