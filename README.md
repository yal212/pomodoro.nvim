# pomodoro.nvim

A Pomodoro timer for developers who live in Neovim. Work / break cycles, editor-native notifications, per-day stats, optional focus mode, statusline component, and a Telescope picker — no required runtime dependencies.

> Status: alpha. Neovim 0.10+.

## Why

You already context-switch through Neovim — your timer should live there too. `pomodoro.nvim` runs cycles inside the editor, fires `vim.notify` so it lights up nvim-notify or noice if you have them, and persists per-day completion counts so you can answer "did I actually focus today?".

## Features

- 25 / 5 / 15 minute defaults (configurable), long break every 4th cycle
- Auto-start breaks, manual confirm before next work block (configurable both ways)
- `vim.notify` and/or floating-window notifications
- Toggleable always-on floating status window with live countdown
- Renderer-agnostic statusline component (lualine recipe included)
- JSON stats persisted under `stdpath('data')`, atomic writes, corrupt-file safe
- Optional focus mode — block chosen `:` commands during work blocks
- Optional Telescope picker for the last 30 days
- `:checkhealth pomodoro`

## Install

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "yal212/pomodoro.nvim",
  opts = {},
  cmd = {
    "PomodoroStart", "PomodoroPause", "PomodoroResume",
    "PomodoroStop",  "PomodoroSkip",  "PomodoroStatus",
    "PomodoroStats", "PomodoroReset",
  },
}
```

[packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use({ "yal212/pomodoro.nvim", config = function() require("pomodoro").setup({}) end })
```

## Quickstart

```vim
:PomodoroStart           " starts a 25-minute work block
:PomodoroStatus          " toggle the floating status window
:PomodoroPause           " pause; remaining time preserved
:PomodoroResume
:PomodoroStop
:PomodoroStats           " today + last 7 days
:checkhealth pomodoro
```

Ring a system bell when a break starts:

```lua
require("pomodoro").setup({
  hooks = {
    on_break_start = function()
      vim.fn.jobstart({ "terminal-notifier", "-message", "Break time" })
    end,
  },
})
```

## Configuration

Full defaults:

```lua
require("pomodoro").setup({
  durations = { work = 25, short_break = 5, long_break = 15 }, -- minutes
  cycles_per_long_break = 4,
  auto_start_break = true,
  auto_start_work  = false,
  notify_styles    = { "vim_notify", "float" },
  notify           = { float_duration_ms = 4000, sound = false },
  statusline       = { icon = "", show_when_idle = false, format = "%s %s" },
  status_window    = {
    border = "rounded", width = 30, height = 5,
    anchor = "NE", row = 1, col_offset = 2, refresh_ms = 1000,
  },
  focus = {
    enabled = false,
    blocked_commands = {},     -- e.g. { "Lazy", "Mason", "Telescope" }
    silent_diagnostics = false,
  },
  persistence = { enabled = true, path = nil },
  hooks = {
    on_work_start  = nil,
    on_work_end    = nil,
    on_break_start = nil,
    on_break_end   = nil,
    on_cycle_complete = nil,
  },
})
```

## Lualine recipe

```lua
require("lualine").setup({
  sections = {
    lualine_x = {
      function() return require("pomodoro.statusline").component() end,
      "encoding", "fileformat", "filetype",
    },
  },
})
```

For colored output:

```lua
local function pomo()
  local s = require("pomodoro.statusline").component_lualine()
  if s.text == "" then return "" end
  return "%#" .. s.hl .. "#" .. s.text
end
```

## Focus mode

Opt-in command guard during work:

```lua
require("pomodoro").setup({
  focus = {
    enabled = true,
    blocked_commands = { "Lazy", "Mason", "Telescope" },
    silent_diagnostics = true,
  },
})
```

Hides `vim.diagnostic` virtual_text during work, restores on break. The
command guard is permissive — only commands you list are blocked.

## Telescope

If telescope is installed:

```vim
:Telescope pomodoro stats
```

Shows the last 30 days; preview pane shows that day's breakdown.

## Tests

```sh
nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/pomodoro/ {minimal_init = 'tests/minimal_init.lua'}"
```

## License

MIT — see [LICENSE](./LICENSE).
