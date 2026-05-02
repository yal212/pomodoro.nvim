local Config = require("pomodoro.config")
local State = require("pomodoro.state")
local Cycle = require("pomodoro.cycle")

local M = {}

local function format_remaining(ms)
  local total_seconds = math.floor(ms / 1000)
  local minutes = math.floor(total_seconds / 60)
  local seconds = total_seconds % 60
  return string.format("%02d:%02d", minutes, seconds)
end

local function hl_for(phase)
  if phase == State.PHASE.WORK then
    return "DiagnosticWarn"
  elseif phase == State.PHASE.SHORT_BREAK or phase == State.PHASE.LONG_BREAK then
    return "DiagnosticOk"
  elseif phase == State.PHASE.PAUSED then
    return "DiagnosticHint"
  end
  return "Comment"
end

function M.text()
  local opts = Config.get()
  local c = State.current
  if c.phase == State.PHASE.IDLE then
    if opts.statusline.show_when_idle then
      return string.format(opts.statusline.format, opts.statusline.icon, "Idle")
    end
    return ""
  end
  local label = Cycle.label(c.phase)
  local remaining = State.remaining_ms()
  local body
  if c.phase == State.PHASE.PAUSED then
    body = string.format("%s %s", label, format_remaining(c.remaining_ms or 0))
  else
    body = string.format("%s %s", label, format_remaining(remaining))
  end
  return string.format(opts.statusline.format, opts.statusline.icon, body)
end

function M.component()
  return M.text()
end

function M.component_lualine()
  return { text = M.text(), hl = hl_for(State.current.phase) }
end

M.format_remaining = format_remaining

local redraw_handle

function M.start_redraw_loop(interval_ms)
  M.stop_redraw_loop()
  if not interval_ms or interval_ms <= 0 then
    return
  end
  redraw_handle = vim.uv.new_timer()
  if not redraw_handle then
    return
  end
  redraw_handle:start(
    interval_ms,
    interval_ms,
    vim.schedule_wrap(function()
      if State.is_running() then
        vim.cmd("redrawstatus")
      end
    end)
  )
end

function M.stop_redraw_loop()
  if redraw_handle and not redraw_handle:is_closing() then
    redraw_handle:stop()
    redraw_handle:close()
  end
  redraw_handle = nil
end

return M
