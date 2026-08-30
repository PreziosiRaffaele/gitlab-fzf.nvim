# prview.nvim

Browse open GitLab merge requests and inspect each full diff in a single
fzf-lua picker. PRView does not change local repository or GitLab state.

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
  'prview.nvim',
  dependencies = { 'ibhagwan/fzf-lua' },
  opts = {},
}
```

## Usage

Run `:PRView` and highlight an open merge request to load its complete,
scrollable GitLab diff in the preview. Delta colors the diff when installed;
raw diff syntax is the fallback. Press `Ctrl-O` to open the highlighted merge
request in GitLab without closing the picker. No external process or dependency
check runs during startup.

## Development

Run `make check`.
