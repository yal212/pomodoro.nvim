-- Init for recording the focus-mode demo gif: nvim --clean -u scripts/demo_focus_init.lua
-- Recorded via `vhs scripts/demo_focus.tape` (see that file for the storyline).
-- Storyline: during a work block, focus mode silences diagnostics, dims the
-- inactive window, and blocks :Lazy / :Mason. On the break, the block lifts.
local cwd = vim.fn.getcwd()
vim.opt.runtimepath:prepend(cwd)
vim.cmd("runtime plugin/pomodoro.lua")

-- Stand-in "distraction" commands. `--clean` has no Lazy/Mason/Telescope, so we
-- define lookalikes that just announce themselves. Focus mode blocks them
-- during work; on the break they run normally, which is the point of the demo.
for _, name in ipairs({ "Lazy", "Mason", "Telescope" }) do
  vim.api.nvim_create_user_command(name, function()
    vim.notify(
      ("(%s) opened — so long, focus"):format(name),
      vim.log.levels.INFO,
      { title = name }
    )
  end, {})
end

require("pomodoro").setup({
  -- Seconds-scale phases so the whole work -> break arc fits in a ~15s gif:
  -- work is 9.6s (long enough for both blocked commands), break is 6s (long
  -- enough to show :Lazy running again, short enough that we never reach the
  -- continue/stop prompt on camera).
  durations = { work = 0.16, short_break = 0.1, long_break = 0.25 },
  auto_start_break = true, -- work rolls into the break on camera, no prompt
  auto_start_work = false, -- recording ends during the break, before any prompt
  statusline = { icon = "🍅", show_when_idle = true },
  focus = {
    enabled = true,
    blocked_commands = { "Lazy", "Mason", "Telescope" },
    silent_diagnostics = true,
    dim_inactive = true,
  },
  persistence = { enabled = false }, -- throwaway; don't touch the user's stats
})

-- Sub-minute demo durations would render as "— 0 min" in notifications; drop
-- the suffix rather than show a misleading number.
local notify = require("pomodoro.notify")
local send = notify.send
notify.send = function(msg, ...)
  return send((msg:gsub(" — 0 min$", "")), ...)
end

vim.o.termguicolors = true
vim.o.number = true
vim.o.laststatus = 3
vim.o.statusline = " %f %m %= %{v:lua.require('pomodoro').statusline()} "

-- Demo-only: punch up `dim_inactive` so it reads on camera. The real default
-- links PomodoroDimNC to Comment, which is deliberately gentle — but NormalNC
-- only recolors text the syntax groups don't already own, so on a syntax-lit
-- buffer a fg-only change is nearly invisible. Darkening the *background* is
-- what actually makes the inactive window recede in a gif. Set explicitly (not
-- `default`) so the plugin's `default = true` link won't clobber it.
vim.api.nvim_set_hl(0, "PomodoroDimNC", { fg = "#45475a", bg = "#11111b" })

-- Open a buffer, then a vertical split so `dim_inactive` has an inactive window
-- to visibly mute. Keep the cursor on the left.
vim.cmd.edit("lua/pomodoro/timer.lua")
vim.cmd("vsplit lua/pomodoro/focus.lua")
vim.cmd("wincmd h")

-- Make virtual-text diagnostics reliably visible up front so `silent_diagnostics`
-- has something to hide when work starts (and restore when the break begins).
vim.diagnostic.config({ virtual_text = true })
local ns = vim.api.nvim_create_namespace("pomodoro_demo_diag")
vim.diagnostic.set(ns, 0, {
  {
    lnum = 4,
    col = 0,
    severity = vim.diagnostic.severity.ERROR,
    message = "undefined global `foo`",
  },
  { lnum = 9, col = 0, severity = vim.diagnostic.severity.WARN, message = "unused local `bar`" },
})
