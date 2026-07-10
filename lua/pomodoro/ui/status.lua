local Config = require("pomodoro.config")
local State = require("pomodoro.state")
local Cycle = require("pomodoro.cycle")
local Statusline = require("pomodoro.statusline")
local Highlights = require("pomodoro.ui.highlights")

local M = {}

local NS = vim.api.nvim_create_namespace("pomodoro_status")
local FILL = "█"
local TRACK = "░"

local win, buf, refresh_handle, resize_group

local function close_refresh()
  if refresh_handle and not refresh_handle:is_closing() then
    refresh_handle:stop()
    refresh_handle:close()
  end
  refresh_handle = nil
end

local function phase_icon(phase, icons)
  if phase == State.PHASE.WORK then
    return icons.work or ""
  elseif phase == State.PHASE.SHORT_BREAK then
    return icons.short_break or ""
  elseif phase == State.PHASE.LONG_BREAK then
    return icons.long_break or ""
  elseif phase == State.PHASE.PAUSED then
    return icons.paused or ""
  end
  return icons.idle or ""
end

local function center(s, width)
  local n = vim.api.nvim_strwidth(s)
  if n >= width then
    return s
  end
  local left = math.floor((width - n) / 2)
  return string.rep(" ", left) .. s .. string.rep(" ", width - n - left)
end

local function build()
  local opts = Config.get()
  local sw = opts.status_window
  local c = State.current
  local inner = sw.width
  local lines, hls = {}, {}

  local function push(line, hl)
    table.insert(lines, line)
    if hl then
      table.insert(hls, { line = #lines - 1, hl = hl })
    end
  end

  if c.phase == State.PHASE.IDLE then
    local icon = phase_icon(State.PHASE.IDLE, sw.icons)
    local header = icon ~= "" and (icon .. "  Idle") or "Idle"
    push(center(header, inner), "PomodoroIdle")
    push("")
    push(center(":Pomodoro start", inner), "PomodoroDim")
    while #lines < sw.height do
      push("")
    end
    return lines, hls
  end

  local label_phase = c.phase == State.PHASE.PAUSED and (c.paused_from or State.PHASE.WORK)
    or c.phase
  local label = Cycle.label(label_phase)
  if c.phase == State.PHASE.PAUSED then
    label = label .. " (paused)"
  end
  local total_ms = c.duration_ms or Cycle.duration_ms(label_phase, opts.durations)
  local remaining_ms
  if c.phase == State.PHASE.PAUSED then
    remaining_ms = c.remaining_ms or 0
  else
    remaining_ms = State.remaining_ms()
  end
  local time = Statusline.format_remaining(remaining_ms)
  local icon = phase_icon(c.phase, sw.icons)
  local header
  if icon ~= "" then
    header = string.format("%s  %s   %s", icon, label, time)
  else
    header = string.format("%s   %s", label, time)
  end
  push(center(header, inner), Highlights.phase_hl(c.phase))

  push("")

  if sw.show_progress_bar then
    local cells = math.max(inner - 2, 1)
    local filled
    if total_ms <= 0 then
      filled = 0
    else
      local elapsed = total_ms - remaining_ms
      filled = math.floor((elapsed / total_ms) * cells + 0.5)
    end
    filled = math.max(0, math.min(filled, cells))
    local bar = string.rep(FILL, filled) .. string.rep(TRACK, cells - filled)
    push(" " .. bar .. " ")
    local fill_bytes = #string.rep(FILL, filled)
    local track_bytes = #string.rep(TRACK, cells - filled)
    local idx = #lines - 1
    if filled > 0 then
      table.insert(hls, {
        line = idx,
        hl = "PomodoroProgress",
        col_start = 1,
        col_end = 1 + fill_bytes,
      })
    end
    if cells - filled > 0 then
      table.insert(hls, {
        line = idx,
        hl = "PomodoroProgressTrack",
        col_start = 1 + fill_bytes,
        col_end = 1 + fill_bytes + track_bytes,
      })
    end
  end

  push("")

  if sw.show_today then
    while #lines < sw.height - 1 do
      push("")
    end
    local done = require("pomodoro.stats").today().completed_work
    local today_str = string.format("today: %d", done)
    if opts.daily_goal and opts.daily_goal > 0 then
      today_str = today_str .. string.format(" / %d", opts.daily_goal)
      local pct = math.floor(done / opts.daily_goal * 100)
      today_str = today_str .. string.format(" (%d%%)", pct)
    end
    push(center(today_str, inner), "PomodoroDim")
  end

  while #lines < sw.height do
    push("")
  end
  while #lines > sw.height do
    table.remove(lines)
  end

  return lines, hls
end

local function render()
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local lines, hls = build()
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for _, h in ipairs(hls) do
    local col_start = h.col_start or 0
    local col_end = h.col_end
    if col_end == nil then
      col_end = #(lines[h.line + 1] or "")
    end
    vim.api.nvim_buf_set_extmark(buf, NS, h.line, col_start, {
      end_row = h.line,
      end_col = col_end,
      hl_group = h.hl,
    })
  end
  vim.bo[buf].modifiable = false
end

function M.is_open()
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function reposition()
  if not M.is_open() then
    return
  end
  local opts = Config.get().status_window
  vim.api.nvim_win_set_config(win, {
    relative = "editor",
    anchor = opts.anchor,
    row = opts.row,
    col = vim.o.columns - opts.col_offset,
  })
end

function M.close()
  close_refresh()
  if resize_group then
    pcall(vim.api.nvim_del_augroup_by_id, resize_group)
    resize_group = nil
  end
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
  Highlights.ensure_highlights()
  local opts = Config.get().status_window
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "pomodoro"
  local win_opts = {
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
  }
  if opts.title and opts.title ~= "" then
    win_opts.title = opts.title
    win_opts.title_pos = opts.title_pos or "center"
  end
  win = vim.api.nvim_open_win(buf, false, win_opts)
  vim.wo[win].winhighlight = "Normal:Normal,FloatBorder:FloatBorder,FloatTitle:PomodoroTitle"
  render()

  resize_group = vim.api.nvim_create_augroup("PomodoroStatusResize", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = resize_group,
    callback = reposition,
  })

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
  else
    vim.notify(
      "pomodoro: failed to start status window refresh timer",
      vim.log.levels.WARN,
      { title = "Pomodoro" }
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
