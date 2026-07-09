---@diagnostic disable: undefined-field
describe("init state machine", function()
  local pomo, State, Stats
  local fake, hook_calls

  local MODULES = {
    "pomodoro",
    "pomodoro.commands",
    "pomodoro.config",
    "pomodoro.cycle",
    "pomodoro.focus",
    "pomodoro.notify",
    "pomodoro.persistence",
    "pomodoro.state",
    "pomodoro.stats",
    "pomodoro.statusline",
    "pomodoro.timer",
  }

  local function hook_recorder(name)
    return function()
      hook_calls[#hook_calls + 1] = name
    end
  end

  local function called(name)
    return vim.tbl_contains(hook_calls, name)
  end

  local function setup(overrides)
    for _, mod in ipairs(MODULES) do
      package.loaded[mod] = nil
    end
    fake = { running = false }
    package.loaded["pomodoro.timer"] = {
      start = function(ms, cb)
        if fake.fail then
          return false
        end
        fake.ms, fake.cb, fake.running = ms, cb, true
        return true
      end,
      stop = function()
        fake.running = false
      end,
      is_running = function()
        return fake.running
      end,
    }
    hook_calls = {}
    pomo = require("pomodoro")
    State = require("pomodoro.state")
    Stats = require("pomodoro.stats")
    pomo.setup(vim.tbl_deep_extend("force", {
      notify_styles = {},
      persistence = { enabled = false },
      hooks = {
        on_work_start = hook_recorder("on_work_start"),
        on_work_end = hook_recorder("on_work_end"),
        on_break_start = hook_recorder("on_break_start"),
        on_break_end = hook_recorder("on_break_end"),
        on_cycle_complete = hook_recorder("on_cycle_complete"),
      },
    }, overrides or {}))
  end

  before_each(function()
    vim.ui.select = function(_, _, on_choice)
      on_choice("Stop")
    end
  end)

  it("start enters WORK with the configured duration", function()
    setup()
    pomo.start()
    assert.equals(State.PHASE.WORK, State.current.phase)
    assert.equals(25 * 60 * 1000, fake.ms)
    assert.is_true(called("on_work_start"))
  end)

  it("natural work completion records stats and auto-starts the break", function()
    setup({ auto_start_break = true })
    pomo.start()
    fake.cb()
    assert.equals(1, Stats.today().completed_work)
    assert.equals(State.PHASE.SHORT_BREAK, State.current.phase)
    assert.is_true(called("on_work_end"))
  end)

  it("skip during WORK records nothing but advances to a break", function()
    setup({ auto_start_break = true })
    pomo.start()
    local idx_before = State.current.cycle_index
    pomo.skip()
    assert.equals(0, Stats.today().completed_work)
    assert.is_false(called("on_work_end"))
    assert.equals(idx_before, State.current.cycle_index)
    assert.equals(State.PHASE.SHORT_BREAK, State.current.phase)
  end)

  it("skip during a break fires no on_break_end hook", function()
    setup({ auto_start_break = true, auto_start_work = true })
    pomo.start()
    fake.cb() -- work done -> short break
    hook_calls = {}
    pomo.skip()
    assert.is_false(called("on_break_end"))
    assert.equals(State.PHASE.WORK, State.current.phase)
  end)

  it("skipped long break is not recorded", function()
    setup({ auto_start_break = true, auto_start_work = true, cycles_per_long_break = 1 })
    pomo.start()
    fake.cb() -- work done -> long break (every 1 cycle)
    assert.equals(State.PHASE.LONG_BREAK, State.current.phase)
    pomo.skip()
    assert.equals(0, Stats.today().completed_long_breaks)
  end)

  it("accepts a one-off duration override without touching config", function()
    setup({ auto_start_break = true })
    pomo.start("45")
    assert.equals(State.PHASE.WORK, State.current.phase)
    assert.equals(45 * 60 * 1000, fake.ms)
    assert.equals(45 * 60 * 1000, State.current.duration_ms)
    assert.equals(25, require("pomodoro.config").get().durations.work)
    fake.cb()
    assert.equals(45, Stats.today().minutes_focused)
    -- the following break falls back to the configured length
    assert.equals(5 * 60 * 1000, fake.ms)
  end)

  it("rejects non-positive duration overrides", function()
    setup()
    pomo.start("0")
    assert.equals(State.PHASE.IDLE, State.current.phase)
    pomo.start(-5)
    assert.equals(State.PHASE.IDLE, State.current.phase)
  end)

  it("restart keeps a duration override", function()
    setup()
    pomo.start({ minutes = 45 })
    fake.ms = nil
    pomo.restart()
    assert.equals(45 * 60 * 1000, fake.ms)
  end)

  it("stays IDLE when the timer fails to start", function()
    setup()
    fake.fail = true
    pomo.start()
    assert.equals(State.PHASE.IDLE, State.current.phase)
    assert.is_false(called("on_work_start"))
  end)

  it("returns to PAUSED when the timer fails on resume", function()
    setup()
    pomo.start()
    pomo.pause()
    fake.fail = true
    pomo.resume()
    assert.equals(State.PHASE.PAUSED, State.current.phase)
  end)

  it("restart restores the full phase duration", function()
    setup()
    pomo.start()
    fake.ms = nil
    pomo.restart()
    assert.equals(25 * 60 * 1000, fake.ms)
    assert.equals(State.PHASE.WORK, State.current.phase)
  end)
end)
