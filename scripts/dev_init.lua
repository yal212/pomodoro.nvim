-- Standalone dev init: nvim --clean -u scripts/dev_init.lua
local cwd = vim.fn.getcwd()
vim.opt.runtimepath:prepend(cwd)
vim.cmd("runtime plugin/pomodoro.lua")
require("pomodoro").setup({
  durations = { work = 1, short_break = 1, long_break = 1 },
  cycles_per_long_break = 2,
})
print("pomodoro.nvim dev init loaded — try :Pomodoro start")
