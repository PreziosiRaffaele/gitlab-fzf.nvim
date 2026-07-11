# PRView Specification

## Purpose and scope

`prview.nvim` provides read-only browsing of open merge requests belonging to
the GitLab project associated with the current repository. It lists merge
requests, lazily loads their changed files, and previews GitLab-provided patches.
It does not mutate buffers, repository state, branches, or GitLab resources.

## Public API

Call `require('prview').setup()` without feature-specific options. Setup is
idempotent and registers `:PRView`. The startup shim calls it automatically.

## Dependencies and authentication

`glab` and `fzf-lua` are required and checked only when `:PRView` is invoked.
`delta` is optional and is attempted only while rendering a textual patch; raw
unified diff is the fallback. Authentication, project identity, and GitLab host
selection are delegated to `glab`, using `GITLAB_TOKEN` or `glab auth login`.
The plugin never reads or stores a token.

## Behavior

`:PRView` asynchronously requests every page of open merge requests through
`glab api`, ordered by most recent update. Highlighting an entry asynchronously
loads and caches its changed files and displays known line counts. Stale and
cancelled responses are ignored. Selecting a merge request opens the changed-file
picker. Selecting a file previews a complete, in-memory Git-style patch, with
special messages for binary, collapsed, oversized, or unavailable patches.

The browsing flow depends only on `pick_merge_request(items, handlers)` and
`pick_changed_file(items, handlers)`. The production adapter is `fzf-lua`; tests
inject fake picker and process adapters.

Errors are concise and actionable for missing dependencies, repositories and
remotes, authentication, permissions, transport failures, malformed JSON, and
empty results. Error content is sanitized before display.

## Testing

Tests cover request construction and normalization, pagination, errors, patch
construction and fallback, formatting, cancellation, stale callbacks, caching,
the picker seam, deferred startup, and preservation of Neovim and repository
state. Tests require no network, credentials, or external executables.
