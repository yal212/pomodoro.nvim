local M = {}

local handle = nil

local function close()
  if handle and not handle:is_closing() then
    handle:stop()
    handle:close()
  end
  handle = nil
end

--- @return boolean started
function M.start(duration_ms, on_expire)
  close()
  handle = vim.uv.new_timer()
  if not handle then
    vim.notify("pomodoro: failed to create timer", vim.log.levels.ERROR, { title = "Pomodoro" })
    return false
  end
  local this = handle
  handle:start(
    duration_ms,
    0,
    vim.schedule_wrap(function()
      -- The expiry is queued on the main loop, so stop()/start() may have
      -- replaced the handle in the meantime; a stale expiry must neither
      -- close the new timer nor end a phase that already ended.
      if handle ~= this then
        return
      end
      close()
      if on_expire then
        on_expire()
      end
    end)
  )
  return true
end

function M.stop()
  close()
end

function M.is_running()
  return handle ~= nil and not handle:is_closing()
end

return M
