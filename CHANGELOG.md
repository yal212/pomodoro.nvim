# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `<Plug>` mappings for every action — `<Plug>(PomodoroStart)`,
  `(PomodoroPause)`, `(PomodoroResume)`, `(PomodoroStop)`, `(PomodoroSkip)`,
  `(PomodoroRestart)`, `(PomodoroStatus)`, `(PomodoroStats)`,
  `(PomodoroHistory)` — available without calling `setup()`
- `setup()` now validates `status_window`, `statusline`, `notify`,
  `persistence`, and `focus` options with clear error messages instead of
  failing later with raw runtime errors
- Test coverage for the statusline component, status window rendering
  (progress bar and daily-goal math), notifications, and `<Plug>` mappings
  (~40 new specs)

### Changed

- The statusline refresh timer now runs only while a phase is counting down
  instead of ticking every `refresh_ms` for the lifetime of the session
- `:checkhealth pomodoro` reports a missing (optional) telescope.nvim as
  information rather than a warning, so a healthy install checks out clean

### Fixed

- Focus mode now blocks commands reached through a mapping, not just ones
  typed at the `:` prompt — `<cmd>Lazy<cr>` behind `<leader>l` was previously
  waved straight through. Listed commands are swapped for a stub during a work
  block and restored exactly as they were when it ends; a command that cannot
  be verifiably restored is left alone
- Answering the Continue/Stop prompt after starting or stopping a phase no
  longer clobbers it — a `:Pomodoro start 45` block could be silently replaced
  by a short break when a stale prompt was answered late
- `:Pomodoro history` no longer drifts off-screen when the day count exceeds
  the window height; the panel is clamped to the screen and scrolls
- Concurrent Neovim instances no longer overwrite each other's stats: saves
  re-read `stats.json` and merge this instance's per-day deltas on top

## [1.0.0] - 2026-07-10

First stable release. 🍅

### Added

- Classic Pomodoro cycles — 25 / 5 / 15 defaults, long break every 4th work
  block, fully configurable; one-off durations with `:Pomodoro start 45`
- Per-day stats, history, and streaks — persisted atomically as JSON;
  `:Pomodoro stats`, `:Pomodoro history`, and an optional Telescope picker
- Pinned status window — borderless card with phase-colored header, live
  progress bar, and today counter
- Focus mode (opt-in) — block distracting `:` commands during work blocks,
  optionally mute diagnostics and dim inactive windows
- Editor-native notifications via `vim.notify` (plays nice with
  nvim-notify / noice) and/or a transient float; opt-in sound on phase end
- Statusline component — drop-in for lualine, heirline, or plain
  `'statusline'`
- Lifecycle hooks — `on_work_start`, `on_break_start`, `on_cycle_complete`,
  and friends
- `:checkhealth pomodoro`, LuaCATS-annotated config, vimdoc at
  `:help pomodoro`
- 80 plenary-busted specs, CI on stable + nightly Neovim

[Unreleased]: https://github.com/yal212/pomodoro.nvim/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/yal212/pomodoro.nvim/releases/tag/v1.0.0
