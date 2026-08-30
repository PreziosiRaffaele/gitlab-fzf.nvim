# GitLab Fzf Specification

## Purpose and scope

`gitlab-fzf.nvim` provides read-only browsing of open merge requests belonging
to the GitLab project associated with the current repository. One `fzf-lua`
picker lists merge requests and shows the complete raw diff returned by GitLab
for the focused entry. GitLab Fzf does not mutate user buffers, the working
tree, the index, `HEAD`, Git refs, or GitLab resources.

## Public API

Call `require('gitlab-fzf').setup(opts)`. Setup is idempotent, registers
`:GitLabFzf`, and accepts an optional `fzf_lua` table containing per-picker
fzf-lua options. Its default is `{ winopts = { fullscreen = true } }`. User
values are deep-merged over that default; setting `winopts.fullscreen = false`
restores a non-fullscreen picker. Each setup call replaces prior settings.
Invalid types and unknown top-level GitLab Fzf options produce clear errors.
The startup shim calls setup with defaults automatically.

## Dependencies and authentication

`glab` and `fzf-lua` are required and checked only when `:GitLabFzf` is invoked.
`delta` is optional. Authentication, project identity, and GitLab host selection
are delegated to `glab`, using `GITLAB_TOKEN` or `glab auth login`. The plugin
never reads or stores a token. No external process or dependency check runs at
startup.

## Behavior

`:GitLabFzf` asynchronously requests every page of open merge requests through
`glab api`, ordered by most recent update. Each raw picker entry contains a
hidden numeric selection index followed by a visible line in the form
`!<iid> (<updated>) <title> <@author>`. The picker header labels this format
as `MR Number (Last Updated Time) Title <Author>`. The hidden index is
tab-delimited from the visible line; fzf expands tabs with a tab stop of four
by default, and users may override the tab stop through `fzf_lua.fzf_opts`.
The request uses glab's `:fullpath` placeholder so nested project paths are
requested directly without a preliminary project-ID lookup.
GitLab Fzf performs no manual column padding or truncation. It wraps the IID in
yellow, the parenthesized update time in green, and the angle-bracketed author
in blue, matching fzf-lua's git commit picker, and enables fzf `--ansi` so those
colors render. The title stays uncolored. The visible IID, update time, title,
and author remain searchable because fzf strips ANSI codes while matching.
Control characters in GitLab-provided display fields are replaced with spaces
before the entry is assembled. Draft state is omitted from picker rows.

GitLab Fzf forwards resolved `fzf_lua` settings to the picker invocation. Users
may customize presentation and add actions. GitLab Fzf retains its diff
previewer, encoded selection field, visible line format, default and `Ctrl-O`
actions, and cancellation on close. A configured `winopts.on_close` callback
runs after GitLab Fzf cleanup.

Focusing an entry asynchronously runs
`glab mr diff <iid> --raw --color=never`. The preview first shows a loading
message, then the complete scrollable raw diff returned by GitLab. A plain-text
header above loading, error, and diff content shows the raw diff state only.
GitLab's own merge request diff limits still apply.
Empty output produces a concise no-textual-changes message.

When Delta is executable, GitLab Fzf passes the raw diff to
`delta --paging=never` and displays its fully formatted ANSI output, including
Delta's file and hunk headers. Delta reads the user's existing configuration.
If Delta is missing or fails, GitLab Fzf displays the raw content with Neovim's
`diff` syntax.

Diff loading and rendering are lazy, cancellable, protected from stale
callbacks, and cached per project and merge request. Moving focus cancels the
active GitLab or Delta process. Successful previews are reused. A failed GitLab
diff request replaces the loading message and is retried when the entry is
focused again. Closing GitLab Fzf cancels active work and ignores late callbacks.

There is no second picker and no local revision preparation. Enter is a
non-closing no-op because focus drives the browsing experience. The picker
closes through its normal cancel action.

Pressing `Ctrl-O` opens the highlighted merge request's HTTP(S) `web_url`
through `vim.ui.open()`. The labeled action runs without closing or restarting
the picker and does not send another GitLab request. A missing or invalid URL
and a system-handler failure produce concise errors without closing the picker.

The browsing flow depends only on `pick_merge_request(items, handlers)`. The
GitLab transport exposes `list_merge_requests(callback)` and
`get_merge_request_diff(mr, callback)`. Diff rendering exposes
`render(diff, callback)`. Tests inject fake picker, transport, renderer, process,
and URL-opening adapters.

Errors are concise and actionable for missing dependencies, repositories and
remotes, authentication, permissions, transport failures (including a concise
502 Bad Gateway message), malformed JSON, and empty results. Error content is
sanitized before display.

## Testing

Tests cover renamed command registration; configuration defaults, overrides,
validation and forwarding; construction of the custom previewer against the
pinned real fzf-lua dependency; entry formatting and header, git-log ANSI field
colors, author fallbacks, tab-stop overrides, complete multibyte titles and
remote value sanitization; GitLab normalization and pagination; raw-diff
command construction; identifier validation; Delta rendering and fallback;
friendly preview update metadata; lazy loading; caching; retry; cancellation
and stale callbacks; the single-picker lifecycle; non-closing actions;
URL-handler errors; deferred dependency checks; and error sanitization. Tests
require no network, credentials, or external executables.
