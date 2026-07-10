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
