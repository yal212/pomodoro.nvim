# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
