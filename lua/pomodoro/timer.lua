local M = {}

local handle = nil

local function close()
  if handle and not handle:is_closing() then
    handle:stop()
    handle:close()
  end
  handle = nil
end

function M.start(duration_ms, on_expire)
  close()
  handle = vim.uv.new_timer()
  if not handle then
    error("pomodoro: failed to create libuv timer", 2)
  end
  handle:start(
    duration_ms,
    0,
    vim.schedule_wrap(function()
      close()
      if on_expire then
        on_expire()
      end
    end)
  )
end

function M.stop()
  close()
end

function M.is_running()
  return handle ~= nil and not handle:is_closing()
end

return M
