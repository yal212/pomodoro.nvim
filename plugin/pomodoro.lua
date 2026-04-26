if vim.g.loaded_pomodoro == 1 then
  return
end
vim.g.loaded_pomodoro = 1

if vim.fn.has("nvim-0.10") ~= 1 then
  vim.notify("pomodoro.nvim requires Neovim 0.10+", vim.log.levels.ERROR)
  return
end
