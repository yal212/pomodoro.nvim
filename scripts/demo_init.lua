-- Init for recording the README demo gif: nvim --clean -u scripts/demo_init.lua
-- Recorded via `vhs scripts/demo.tape` (see that file for the storyline).
local cwd = vim.fn.getcwd()
vim.opt.runtimepath:prepend(cwd)
vim.cmd("runtime plugin/pomodoro.lua")

-- Throwaway stats file seeded with a plausible week so history/streak look alive.
local stats_path = vim.fn.tempname() .. "-pomodoro-demo.json"
local days = {}
local per_day = { [0] = 3, 5, 6, 4, 7, 5 }
for ago, blocks in pairs(per_day) do
  local key = os.date("%Y-%m-%d", os.time() - ago * 86400)
  days[key] = {
    completed_work = blocks,
    completed_long_breaks = math.floor(blocks / 4),
    minutes_focused = blocks * 25,
  }
end
vim.fn.mkdir(vim.fs.dirname(stats_path), "p")
vim.fn.writefile({ vim.json.encode({ version = 1, days = days }) }, stats_path)

require("pomodoro").setup({
  -- Seconds-scale phases so a full work -> break -> work arc fits in the gif.
  durations = { work = 0.2, short_break = 0.1, long_break = 0.2 },
  auto_start_break = true,
  auto_start_work = true,
  daily_goal = 4,
  statusline = { icon = "🍅", show_when_idle = true },
  persistence = { path = stats_path },
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
vim.cmd.edit("lua/pomodoro/timer.lua")
