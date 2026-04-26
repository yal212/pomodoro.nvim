-- Minimal init for plenary-busted test runs.
local cwd = vim.fn.getcwd()
local deps_dir = cwd .. "/tests/.deps"
local plenary = deps_dir .. "/plenary.nvim"

if vim.fn.isdirectory(plenary) == 0 then
  vim.fn.mkdir(deps_dir, "p")
  vim.fn.system({
    "git",
    "clone",
    "--depth=1",
    "https://github.com/nvim-lua/plenary.nvim",
    plenary,
  })
end

vim.opt.runtimepath:prepend(plenary)
vim.opt.runtimepath:prepend(cwd)
vim.cmd("runtime plugin/plenary.vim")
vim.cmd("runtime plugin/pomodoro.lua")
