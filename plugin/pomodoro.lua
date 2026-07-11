if vim.g.loaded_pomodoro == 1 then
  return
end
vim.g.loaded_pomodoro = 1

if vim.fn.has("nvim-0.10") ~= 1 then
  vim.notify("pomodoro.nvim requires Neovim 0.10+", vim.log.levels.ERROR)
  return
end

-- Register :Pomodoro eagerly so the plugin works without setup(); the module
-- itself is only required on first use.
require("pomodoro.commands").register()

-- <Plug> mappings route through :Pomodoro so first use still runs the
-- setup-with-defaults path in commands.dispatch().
for plug, sub in pairs({
  ["<Plug>(PomodoroStart)"] = "start",
  ["<Plug>(PomodoroPause)"] = "pause",
  ["<Plug>(PomodoroResume)"] = "resume",
  ["<Plug>(PomodoroStop)"] = "stop",
  ["<Plug>(PomodoroSkip)"] = "skip",
  ["<Plug>(PomodoroRestart)"] = "restart",
  ["<Plug>(PomodoroStatus)"] = "status",
  ["<Plug>(PomodoroStats)"] = "stats",
  ["<Plug>(PomodoroHistory)"] = "history",
}) do
  vim.keymap.set("n", plug, "<cmd>Pomodoro " .. sub .. "<CR>", { desc = "Pomodoro: " .. sub })
end
