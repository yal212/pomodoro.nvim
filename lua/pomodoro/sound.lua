local Config = require("pomodoro.config")

local M = {}

local warned = false

--- @return string[]|nil argv for vim.system, or nil when no player is known
function M._resolve_cmd()
  local cmd = Config.get().sound.cmd
  if type(cmd) == "string" then
    return { "sh", "-c", cmd }
  elseif type(cmd) == "table" then
    return cmd
  end
  if vim.uv.os_uname().sysname == "Darwin" then
    return { "afplay", "/System/Library/Sounds/Glass.aiff" }
  end
  return nil
end

local function warn_once(msg)
  if warned then
    return
  end
  warned = true
  vim.schedule(function()
    vim.notify("pomodoro: " .. msg, vim.log.levels.WARN, { title = "Pomodoro" })
  end)
end

--- Play the phase-end sound, non-blocking. No-op unless sound.enabled.
function M.play()
  if not Config.get().sound.enabled then
    return
  end
  local cmd = M._resolve_cmd()
  if not cmd then
    warn_once("sound.enabled is set but no sound.cmd configured for this platform")
    return
  end
  local ok, err = pcall(vim.system, cmd, {}, function(out)
    if out.code ~= 0 then
      warn_once(("sound command failed (exit %d): %s"):format(out.code, table.concat(cmd, " ")))
    end
  end)
  if not ok then
    warn_once("could not run sound command: " .. tostring(err))
  end
end

return M
