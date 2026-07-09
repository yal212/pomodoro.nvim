local M = {}

local function start(...)
  return (vim.health.start or vim.health.report_start)(...)
end
local function ok(...)
  return (vim.health.ok or vim.health.report_ok)(...)
end
local function warn(...)
  return (vim.health.warn or vim.health.report_warn)(...)
end
local function error_(...)
  return (vim.health.error or vim.health.report_error)(...)
end

function M.check()
  start("pomodoro.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    ok("Neovim >= 0.10")
  else
    error_("Neovim 0.10+ required")
  end

  local pom_ok, pom = pcall(require, "pomodoro")
  if pom_ok and pom._is_setup() then
    ok("setup() called")
  else
    warn("setup() not called yet — call require('pomodoro').setup()")
  end

  local data_dir = vim.fn.stdpath("data")
  if vim.fn.isdirectory(data_dir) == 1 then
    ok("data dir writable: " .. data_dir)
  else
    warn("data dir missing: " .. data_dir)
  end

  local sound = require("pomodoro.config").get().sound
  if sound and sound.enabled then
    local cmd = require("pomodoro.sound")._resolve_cmd()
    if not cmd then
      warn("sound.enabled is set but no sound.cmd configured for this platform")
    elseif vim.fn.executable(cmd[1]) == 1 then
      ok("sound command found: " .. cmd[1])
    else
      warn("sound command not executable: " .. cmd[1])
    end
  end

  if pcall(require, "telescope") then
    ok("telescope.nvim found (optional picker available)")
  else
    warn("telescope.nvim not installed (optional)")
  end

  if pcall(require, "notify") then
    ok("nvim-notify detected — vim.notify will use it")
  end
end

return M
