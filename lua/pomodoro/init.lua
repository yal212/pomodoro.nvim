local Config = require("pomodoro.config")
local State = require("pomodoro.state")
local Timer = require("pomodoro.timer")
local Cycle = require("pomodoro.cycle")
local Notify = require("pomodoro.notify")
local Stats = require("pomodoro.stats")
local Focus = require("pomodoro.focus")

local M = {}

local function call_hook(name, payload)
  local hooks = Config.get().hooks or {}
  local fn = hooks[name]
  if type(fn) == "function" then
    pcall(fn, payload or {})
  end
end

local function start_phase(phase)
  local opts = Config.get()
  local duration_ms = Cycle.duration_ms(phase, opts.durations)
  if duration_ms <= 0 then
    return
  end
  State.set_phase(phase, duration_ms)

  if phase == State.PHASE.WORK then
    Notify.send(string.format("Work started — %d min", opts.durations.work))
    Focus.on_work_start()
    call_hook("on_work_start", { duration_min = opts.durations.work })
  elseif phase == State.PHASE.SHORT_BREAK then
    Notify.send(string.format("Short break — %d min", opts.durations.short_break))
    call_hook("on_break_start", { kind = "short", duration_min = opts.durations.short_break })
  elseif phase == State.PHASE.LONG_BREAK then
    Notify.send(string.format("Long break — %d min", opts.durations.long_break))
    call_hook("on_break_start", { kind = "long", duration_min = opts.durations.long_break })
  end

  Timer.start(duration_ms, function()
    M._on_phase_end(phase)
  end)
end

function M._on_phase_end(phase)
  local opts = Config.get()

  if phase == State.PHASE.WORK then
    State.current.cycle_index = State.current.cycle_index + 1
    State.current.completed_today = State.current.completed_today + 1
    Stats.record_work_complete()
    Focus.on_work_end()
    call_hook("on_work_end", { cycle_index = State.current.cycle_index })

    local next_phase = Cycle.next_after_work(State.current.cycle_index, opts.cycles_per_long_break)
    if next_phase == State.PHASE.LONG_BREAK then
      State.current.cycle_index = 0
      call_hook("on_cycle_complete", {})
    end
    if opts.auto_start_break then
      start_phase(next_phase)
    else
      State.set_phase(State.PHASE.IDLE, 0)
      Notify.send("Work complete. Run :PomodoroStart to begin break.")
    end
  elseif phase == State.PHASE.SHORT_BREAK or phase == State.PHASE.LONG_BREAK then
    if phase == State.PHASE.LONG_BREAK then
      Stats.record_long_break_complete()
    end
    call_hook("on_break_end", { kind = phase == State.PHASE.LONG_BREAK and "long" or "short" })

    if opts.auto_start_work then
      start_phase(State.PHASE.WORK)
    else
      State.set_phase(State.PHASE.IDLE, 0)
      Notify.send("Break over. Run :PomodoroStart to resume work.")
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

function M.start(arg)
  local target
  if arg == "work" then
    target = State.PHASE.WORK
  elseif arg == "short" then
    target = State.PHASE.SHORT_BREAK
  elseif arg == "long" then
    target = State.PHASE.LONG_BREAK
  elseif State.current.phase == State.PHASE.PAUSED then
    return M.resume()
  elseif State.is_running() then
    Notify.send("Already running. :PomodoroStop first.", "warn")
    return
  else
    target = next_phase_from_idle()
  end
  Timer.stop()
  start_phase(target)
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
  Timer.start(remaining, function()
    M._on_phase_end(prev_phase)
  end)
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
  M._on_phase_end(phase)
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
    "",
  }
  for _, row in ipairs(week) do
    lines[#lines + 1] = string.format("  %s  %d", row.date, row.data.completed_work)
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Pomodoro" })
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
  did_setup = true
end

function M._is_setup()
  return did_setup
end

return M
