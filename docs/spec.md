# PRView Specification

## Purpose and scope

`prview.nvim` provides read-only browsing of open merge requests belonging to
the GitLab project associated with the current repository. One `fzf-lua`
picker lists merge requests and shows the complete raw diff returned by GitLab
for the focused entry. PRView does not mutate user buffers, the working tree,
the index, `HEAD`, Git refs, or GitLab resources.

## Public API

Call `require('prview').setup()` without feature-specific options. Setup is
idempotent and registers `:PRView`. The startup shim calls it automatically.

## Dependencies and authentication

`glab` and `fzf-lua` are required and checked only when `:PRView` is invoked.
`delta` is optional. Authentication, project identity, and GitLab host selection
are delegated to `glab`, using `GITLAB_TOKEN` or `glab auth login`. The plugin
never reads or stores a token. No external process or dependency check runs at
startup.

## Behavior

`:PRView` asynchronously requests every page of open merge requests through
`glab api`, ordered by most recent update. Entries show the merge request IID,
draft status, title, author, source and target branches, and update time.

Focusing an entry asynchronously runs
`glab mr diff <iid> --raw --color=never`. The preview first shows a loading
message, then the complete scrollable raw diff returned by GitLab. GitLab's own
merge request diff limits still apply. Empty output produces a concise
no-textual-changes message.

When Delta is executable, PRView passes the raw diff to
`delta --paging=never --color-only` and displays its ANSI output. If Delta is
missing or fails, PRView displays the raw content with Neovim's `diff` syntax.

Diff loading and rendering are lazy, cancellable, protected from stale
callbacks, and cached per project and merge request. Moving focus cancels the
active GitLab or Delta process. Successful previews are reused. A failed GitLab
diff request replaces the loading message and is retried when the entry is
focused again. Closing PRView cancels active work and ignores late callbacks.

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
remotes, authentication, permissions, transport failures, malformed JSON, and
empty results. Error content is sanitized before display.

## Testing

Tests cover GitLab normalization and pagination, raw-diff command construction,
identifier validation, Delta rendering and fallback, lazy loading, caching,
retry, cancellation and stale callbacks, the single-picker lifecycle,
non-closing actions, URL-handler errors, deferred dependency checks, and error
sanitization. Tests require no network, credentials, or external executables.
