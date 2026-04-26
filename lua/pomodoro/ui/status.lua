local Config = require("pomodoro.config")
local State = require("pomodoro.state")
local Cycle = require("pomodoro.cycle")
local Statusline = require("pomodoro.statusline")

local M = {}

local win, buf, refresh_handle

local function close_refresh()
  if refresh_handle and not refresh_handle:is_closing() then
    refresh_handle:stop()
    refresh_handle:close()
  end
  refresh_handle = nil
end

local function lines()
  local c = State.current
  if c.phase == State.PHASE.IDLE then
    return {
      "  Pomodoro: idle",
      "",
      "  :PomodoroStart",
    }
  end
  local label = Cycle.label(c.phase)
  local remaining
  if c.phase == State.PHASE.PAUSED then
    remaining = Statusline.format_remaining(c.remaining_ms or 0)
  else
    remaining = Statusline.format_remaining(State.remaining_ms())
  end
  return {
    string.format("  %s", label),
    string.format("  %s remaining", remaining),
    string.format("  cycle %d", c.cycle_index),
    string.format("  today %d", c.completed_today),
  }
end

local function render()
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines())
  vim.bo[buf].modifiable = false
end

function M.is_open()
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

function M.close()
  close_refresh()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  win, buf = nil, nil
end

function M.open()
  if M.is_open() then
    return
  end
  local opts = Config.get().status_window
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "pomodoro"
  win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    anchor = opts.anchor,
    width = opts.width,
    height = opts.height,
    row = opts.row,
    col = vim.o.columns - opts.col_offset,
    style = "minimal",
    border = opts.border,
    focusable = false,
    noautocmd = true,
  })
  vim.wo[win].winhighlight = "Normal:Normal,FloatBorder:FloatBorder"
  render()

  close_refresh()
  refresh_handle = vim.uv.new_timer()
  if refresh_handle then
    refresh_handle:start(
      opts.refresh_ms,
      opts.refresh_ms,
      vim.schedule_wrap(function()
        if M.is_open() then
          render()
        else
          close_refresh()
        end
      end)
    )
  end
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

function M.refresh()
  render()
end

return M
