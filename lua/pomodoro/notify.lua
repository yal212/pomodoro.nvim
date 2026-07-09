local Config = require("pomodoro.config")
local Float = require("pomodoro.ui.float")

local M = {}

function M.send(msg, level_name)
  local opts = Config.get()
  local level = vim.log.levels[string.upper(level_name or "info")] or vim.log.levels.INFO
  for _, style in ipairs(opts.notify_styles or {}) do
    if style == "vim_notify" then
      vim.notify(msg, level, { title = "Pomodoro" })
    elseif style == "float" then
      Float.flash({ "  " .. msg .. "  " }, opts.notify.float_duration_ms, "rounded")
    end
  end
end

return M
