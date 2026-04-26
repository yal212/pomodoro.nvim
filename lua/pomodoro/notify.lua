local Config = require("pomodoro.config")
local Float = require("pomodoro.ui.float")

local M = {}

local LEVEL = {
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

function M.send(msg, level_name)
  local opts = Config.get()
  local level = LEVEL[level_name or "info"] or LEVEL.info
  for _, style in ipairs(opts.notify_styles or {}) do
    if style == "vim_notify" then
      vim.notify(msg, level, { title = "Pomodoro" })
    elseif style == "float" then
      Float.flash({ "  " .. msg .. "  " }, opts.notify.float_duration_ms, "rounded")
    end
  end
end

return M
