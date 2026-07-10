# Contributing to pomodoro.nvim

Thanks for your interest in contributing! Issues and pull requests are welcome.

## Development setup

No dependencies to install — clone the repo and you're ready:

```sh
git clone https://github.com/yal212/pomodoro.nvim
cd pomodoro.nvim
```

The test suite self-bootstraps [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
into `tests/.deps/` (gitignored) via `tests/minimal_init.lua` on first run.

## Running tests

The same command CI runs:

```sh
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/pomodoro/ { minimal_init = 'tests/minimal_init.lua' }"
```

To run a single spec file:

```sh
nvim --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/pomodoro/timer_spec.lua"
```

## Formatting and linting

CI enforces both — run them before submitting:

```sh
stylua lua/ tests/ plugin/   # format (config in stylua.toml)
luacheck lua/ plugin/        # lint (config in .luacheckrc)
```

## Commit messages

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

- `feat(stats): streak tracking in stats summary`
- `fix(timer): stale queued expiry raced a replacement timer`
- `docs: sync README with behavior`
- Mark breaking changes with `!` — e.g. `feat(commands)!: ...`

## Guidelines

1. **Add a spec for any new behavior** — tests live in `tests/pomodoro/`
2. **Keep runtime dependencies at zero** — Telescope/notify integrations must
   remain optional
3. **Update docs when behavior changes** — both `README.md` and
   `doc/pomodoro.txt`
4. **Re-record the demo if a change alters the UI** — `vhs scripts/demo.tape`
   ([vhs](https://github.com/charmbracelet/vhs))
5. **Add a `CHANGELOG.md` entry** under `[Unreleased]` for user-facing changes

## Releasing (maintainers)

Releases are cut from tags — the `release` workflow publishes a GitHub release
using the matching `CHANGELOG.md` section as the body:

1. Move the `[Unreleased]` notes into a new `## [X.Y.Z] - YYYY-MM-DD` section
   and update the link footer; merge that via PR
2. Tag and push: `git tag vX.Y.Z && git push origin vX.Y.Z`

The workflow fails if `CHANGELOG.md` has no section for the tag, and marks
tags containing `-` (e.g. `v1.1.0-rc.1`) as prereleases.

## Reporting bugs

Please use the bug report issue template — it asks for `nvim --version`, a
minimal repro config, and `:checkhealth pomodoro` output, which makes issues
much faster to triage.
