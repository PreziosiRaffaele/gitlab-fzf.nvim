# Contributor Guide

## Structure

- `plugin/`: minimal Neovim startup shim only.
- `lua/nvim-plugin-template/`: implementation, organized by responsibility.
- `doc/`: Vim help. Keep help tags and examples aligned with the public API.
- `tests/`: headless `mini.test` suite.

## Practices

- Keep startup work cheap. Defer nonessential work until an explicit command,
  mapping, or user action.
- Prefer small modules with narrow exported APIs. Do not introduce generic
  utility modules without a real cross-cutting responsibility.
- Preserve user buffers, windows, options, and mappings unless the plugin
  explicitly owns them.
- Keep configuration defaults in `lua/nvim-plugin-template/config.lua` and
  validate externally supplied values there.
- When changing a public command, option, or mapping, update both `README.md`
  and `doc/nvim-plugin-template.txt`.

## Specification Workflow

`docs/spec.md` is the source of truth for product behavior, public commands,
configuration, and user-facing flows. Keep `README.md` as a concise quickstart;
do not duplicate the full specification here.

For every feature, follow this sequence:

1. Draft `docs/<feature-name>.md` in the feature branch. Describe the goal,
   configuration, behavior, test cases, and the required changes to the main
   specification. Do not change `docs/spec.md` yet.
2. Implement and test the feature against that feature specification.
3. Apply the agreed changes to `docs/spec.md`, then delete the temporary
   feature specification.

## Verification

Run `make quality` after editing Lua files. Run `make test` for behavior
changes, or `make check` for both. The test dependency is pinned in the
`Makefile`; do not upgrade it incidentally.
