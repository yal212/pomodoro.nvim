local Config = require("pomodoro.config")
local State = require("pomodoro.state")
local Timer = require("pomodoro.timer")
local Cycle = require("pomodoro.cycle")
local Notify = require("pomodoro.notify")
local Stats = require("pomodoro.stats")
local Focus = require("pomodoro.focus")
local Statusline = require("pomodoro.statusline")

local M = {}

local function call_hook(name, payload)
  local hooks = Config.get().hooks or {}
  local fn = hooks[name]
  if type(fn) == "function" then
    pcall(fn, payload or {})
  end
end

local function prompt_continue(next_phase, on_continue)
  local label = Cycle.label(next_phase)
  vim.ui.select({ "Continue → " .. label, "Stop" }, {
    prompt = "Pomodoro: phase complete",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if choice and choice ~= "Stop" then
      on_continue()
    else
      Notify.send("Stopped")
    end
  end)
end

-- override_min: one-off phase length in minutes (:Pomodoro start 45); the
-- configured durations are untouched.
local function start_phase(phase, override_min)
  local opts = Config.get()
  local duration_ms = override_min and math.floor(override_min * 60 * 1000)
    or Cycle.duration_ms(phase, opts.durations)
  if duration_ms <= 0 then
    return
  end
  -- start the timer first so a failure can't leave state "running"
  local started = Timer.start(duration_ms, function()
    M._on_phase_end(phase)
  end)
  if not started then
    return
  end
  State.set_phase(phase, duration_ms)

  local minutes = math.floor(duration_ms / 60000 + 0.5)
  if phase == State.PHASE.WORK then
    Notify.send(string.format("Work started — %d min", minutes))
    Focus.on_work_start()
    call_hook("on_work_start", { duration_min = minutes })
  elseif phase == State.PHASE.SHORT_BREAK then
    Notify.send(string.format("Short break — %d min", minutes))
    call_hook("on_break_start", { kind = "short", duration_min = minutes })
  elseif phase == State.PHASE.LONG_BREAK then
    Notify.send(string.format("Long break — %d min", minutes))
    call_hook("on_break_start", { kind = "long", duration_min = minutes })
  end
end

-- ctx.skipped: the phase was cut short via :Pomodoro skip — advance to the
-- next phase but record no stats and fire no completion hooks.
function M._on_phase_end(phase, ctx)
  ctx = ctx or {}
  local opts = Config.get()

  if not ctx.skipped then
    require("pomodoro.sound").play()
  end

  if phase == State.PHASE.WORK then
    Focus.on_work_end()
    if not ctx.skipped then
      State.current.cycle_index = State.current.cycle_index + 1
      local minutes = State.current.duration_ms
        and math.floor(State.current.duration_ms / 60000 + 0.5)
      Stats.record_work_complete(minutes)
      call_hook("on_work_end", { cycle_index = State.current.cycle_index })
    end

    local next_phase = Cycle.next_after_work(State.current.cycle_index, opts.cycles_per_long_break)
    if next_phase == State.PHASE.LONG_BREAK and not ctx.skipped then
      State.current.cycle_index = 0
      call_hook("on_cycle_complete", {})
    end
    if opts.auto_start_break then
      start_phase(next_phase)
    else
      State.set_phase(State.PHASE.IDLE, 0)
      Notify.send("Work complete")
      prompt_continue(next_phase, function()
        start_phase(next_phase)
      end)
    end
  elseif phase == State.PHASE.SHORT_BREAK or phase == State.PHASE.LONG_BREAK then
    if not ctx.skipped then
      if phase == State.PHASE.LONG_BREAK then
        Stats.record_long_break_complete()
      end
      call_hook("on_break_end", { kind = phase == State.PHASE.LONG_BREAK and "long" or "short" })
    end

    if opts.auto_start_work then
      start_phase(State.PHASE.WORK)
    else
      State.set_phase(State.PHASE.IDLE, 0)
      Notify.send("Break over")
      prompt_continue(State.PHASE.WORK, function()
        start_phase(State.PHASE.WORK)
      end)
    end
  end
end

local function next_phase_from_idle()
  local idx = State.current.cycle_index
  local cpl = Config.get().cycles_per_long_break
  if idx > 0 and idx >= cpl then
    return State.PHASE.LONG_BREAK
  end
  return State.PHASE.WORK
end

--- @param arg string|number|table|nil "work"/"short"/"long", a minute count
---   for a one-off work block, or { minutes = n }
function M.start(arg)
  local override_min
  if type(arg) == "table" then
    override_min = tonumber(arg.minutes)
    arg = nil
  elseif type(arg) == "number" or (type(arg) == "string" and tonumber(arg)) then
    override_min = tonumber(arg)
    arg = nil
  end
  if override_min ~= nil and override_min <= 0 then
    Notify.send("Duration must be a positive number of minutes", "warn")
    return
  end

  local target
  if override_min then
    target = State.PHASE.WORK
  elseif arg == "work" then
    target = State.PHASE.WORK
  elseif arg == "short" then
    target = State.PHASE.SHORT_BREAK
  elseif arg == "long" then
    target = State.PHASE.LONG_BREAK
  elseif State.current.phase == State.PHASE.PAUSED then
    return M.resume()
  elseif State.is_running() then
    Notify.send("Already running. :Pomodoro stop first.", "warn")
    return
  else
    target = next_phase_from_idle()
  end
  Timer.stop()
  start_phase(target, override_min)
end

function M.pause()
  if State.pause() then
    Timer.stop()
    Notify.send("Paused")
  end
end

function M.resume()
  local ok, prev_phase, remaining = State.resume()
  if not ok then
    Notify.send("Nothing to resume", "warn")
    return
  end
  local started = Timer.start(remaining, function()
    M._on_phase_end(prev_phase)
  end)
  if not started then
    State.pause() -- roll back to the paused state
    return
  end
  Notify.send("Resumed")
end

function M.stop()
  Timer.stop()
  Focus.on_work_end()
  State.set_phase(State.PHASE.IDLE, 0)
  Notify.send("Stopped")
end

function M.skip()
  if not State.is_running() then
    Notify.send("Nothing to skip", "warn")
    return
  end
  local phase = State.current.phase
  Timer.stop()
  M._on_phase_end(phase, { skipped = true })
end

function M.restart()
  if not State.is_running() then
    Notify.send("Nothing to restart", "warn")
    return
  end
  local phase = State.current.phase
  local override_min = State.current.duration_ms and State.current.duration_ms / 60000
  Timer.stop()
  start_phase(phase, override_min)
end

function M.status()
  require("pomodoro.ui.status").toggle()
end

function M.stats_summary()
  local today = Stats.today()
  local week = Stats.last_n_days(7)
  local week_total = 0
  for _, row in ipairs(week) do
    week_total = week_total + row.data.completed_work
  end
  local lines = {
    string.format(
      "Today: %d work blocks, %d min focused",
      today.completed_work,
      today.minutes_focused
    ),
    string.format("Last 7 days: %d work blocks", week_total),
    string.format("Streak: %d day(s)", Stats.streak(Config.get().daily_goal)),
    "",
  }
  for _, row in ipairs(week) do
    lines[#lines + 1] = string.format("  %s  %d", row.date, row.data.completed_work)
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Pomodoro" })
end

--- Show the last n days (default 14) in a dismissable float.
function M.history(n)
  n = tonumber(n) or 14
  local rows = Stats.last_n_days(n)
  local lines = { string.format(" Pomodoro — last %d days ", n), "" }
  for _, row in ipairs(rows) do
    local bar = string.rep("█", math.min(row.data.completed_work, 20))
    lines[#lines + 1] = string.format(
      " %s  %2d work  %4d min  %s ",
      row.date,
      row.data.completed_work,
      row.data.minutes_focused,
      bar
    )
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = string.format(" Streak: %d day(s) ", Stats.streak(Config.get().daily_goal))
  require("pomodoro.ui.float").open_panel(lines)
end

function M.reset_stats()
  Stats.reset()
  vim.notify("Pomodoro stats cleared", vim.log.levels.INFO, { title = "Pomodoro" })
end

function M.statusline()
  return require("pomodoro.statusline").component()
end

local function register_persist_autocmd()
  local group = vim.api.nvim_create_augroup("PomodoroPersist", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      Stats.save()
    end,
  })
end

local did_setup = false

function M.setup(user_opts)
  Config.merge(user_opts)
  Stats.load()
  Focus.setup()
  require("pomodoro.commands").register()
  register_persist_autocmd()
  Statusline.start_redraw_loop(Config.get().statusline.refresh_ms)
  did_setup = true
end

function M._is_setup()
  return did_setup
end

return M
