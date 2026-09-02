# GitLab Fzf Specification

## Purpose and scope
`gitlab-fzf.nvim` provides browsing of open merge requests belonging to the
GitLab project associated with the current repository. One `fzf-lua` picker
lists merge requests and shows a compact merge request summary followed by the
complete raw diff returned by GitLab for the focused entry. Browsing is
read-only. The explicit source-branch checkout action may update unmodified
buffers, the working tree, `HEAD`, and local Git refs. GitLab Fzf never mutates
GitLab resources.

## Public API

Call `require('gitlab-fzf').setup(opts)`. Setup is idempotent, registers
`:GitLabFzf`, and accepts an optional `fzf_lua` table containing per-picker
fzf-lua options. Its default is `{ winopts = { fullscreen = true } }`. User
values are deep-merged over that default; setting `winopts.fullscreen = false`
restores a non-fullscreen picker. Each setup call replaces prior settings.
Invalid types and unknown top-level GitLab Fzf options produce clear errors.
The startup shim calls setup with defaults automatically.

## Dependencies and authentication

`glab` 1.80.0 or newer and `fzf-lua` are required and checked only when
`:GitLabFzf` is invoked. `delta` is optional. Authentication, project identity,
and GitLab host selection are delegated to `glab`, using `GITLAB_TOKEN` or
`glab auth login`. The plugin never reads or stores a token. No external process
or dependency check runs at startup.

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
The normalized merge request retains the description, reviewers, labels, and
detailed merge status used by the preview summary in addition to the fields
used by the picker and actions.
GitLab Fzf performs no manual column padding or truncation. It wraps the IID in
yellow, the parenthesized update time in green, and the angle-bracketed author
in blue, matching fzf-lua's git commit picker, and enables fzf `--ansi` so those
colors render. The title stays uncolored. The visible IID, update time, title,
and author remain searchable because fzf strips ANSI codes while matching.
Control characters in GitLab-provided display fields are replaced with spaces
before the entry is assembled. Draft state is omitted from picker rows.

GitLab Fzf forwards resolved `fzf_lua` settings to the picker invocation. Users
may customize presentation and add actions. GitLab Fzf retains its diff
previewer, encoded selection field, visible line format, default, `Ctrl-B`, and
`Ctrl-O` actions, and cancellation on close. A configured `winopts.on_close`
callback runs after GitLab Fzf cleanup.

Focusing an entry asynchronously runs
`glab mr diff <iid> --raw --color=never`. The preview immediately shows a
plain-text summary containing the merge request IID and title; author and
source-to-target branch; draft or detailed merge status; latest update time;
and reviewers, labels, and the first non-empty description paragraph when
present. Remote values are collapsed to single-line text. Description excerpts
longer than 240 characters are truncated with an ellipsis.

The summary appears above a `Diff` heading and the loading, error, or final diff
body. After the raw diff arrives, the summary includes changed areas derived
from its `diff --git` headers. Each unique changed file contributes once and a
rename uses its new path. Files are grouped by their first path segment, with
repository-root files grouped under `[root]`; the root group appears first and
other groups are sorted alphabetically. Git-quoted paths are decoded. No extra
process or network request is made for this list. If no paths can be extracted,
the changed-area section is omitted. GitLab's own merge request diff limits
therefore apply to both the diff and changed areas. Empty output produces a
concise no-textual-changes message.

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

There is no second picker. Enter is a non-closing no-op because focus drives the
browsing experience. The picker closes through its normal cancel action or a
source-branch checkout.

Pressing `Ctrl-O` opens the highlighted merge request's HTTP(S) `web_url`
through `vim.ui.open()`. The labeled action runs without closing or restarting
the picker and does not send another GitLab request. A missing or invalid URL
and a system-handler failure produce concise errors without closing the picker.

Pressing `Ctrl-B` closes the picker and asynchronously runs
`glab mr checkout <iid>` for the highlighted merge request. Delegating checkout
to `glab` supports source branches in both the current project and forks. A
successful checkout runs `:checktime` so unmodified buffers notice files
changed on disk, then displays an informational notification. A failure
displays a sanitized error and does not run `:checktime`. The IID is validated
before the process starts. Checkout may update the working tree, `HEAD`, and
local Git refs, but does not mutate GitLab resources.

The browsing flow depends only on `pick_merge_request(items, handlers)`. The
GitLab transport exposes `list_merge_requests(callback)` and
`get_merge_request_diff(mr, callback)`. Diff rendering exposes
`render(diff, callback)`, and summary rendering exposes `render(mr, diff)`.
Tests inject fake picker, transport, diff renderer, summary renderer, process,
and URL-opening adapters.

Errors are concise and actionable for missing dependencies, repositories and
remotes, authentication, permissions, transport failures (including a concise
502 Bad Gateway message), malformed JSON, and empty results. Error content is
sanitized before display.
