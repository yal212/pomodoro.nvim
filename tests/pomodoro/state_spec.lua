---@diagnostic disable: undefined-field
describe("state machine", function()
  local State

  before_each(function()
    package.loaded["pomodoro.state"] = nil
    State = require("pomodoro.state")
  end)

  it("starts idle", function()
    assert.equals(State.PHASE.IDLE, State.current.phase)
    assert.is_false(State.is_active())
    assert.is_false(State.is_running())
  end)

  it("transitions idle -> work", function()
    State.set_phase(State.PHASE.WORK, 25 * 60 * 1000, 1000)
    assert.equals(State.PHASE.WORK, State.current.phase)
    assert.is_true(State.is_running())
    assert.equals(1000, State.current.started_at)
    assert.equals(1000 + 25 * 60 * 1000, State.current.ends_at)
  end)

  it("remaining_ms decreases as time advances", function()
    State.set_phase(State.PHASE.WORK, 60 * 1000, 0)
    assert.equals(60 * 1000, State.remaining_ms(0))
    assert.equals(30 * 1000, State.remaining_ms(30 * 1000))
    assert.equals(0, State.remaining_ms(120 * 1000)) -- clamped
  end)

  it("pause preserves remaining ms; resume continues", function()
    State.set_phase(State.PHASE.WORK, 60 * 1000, 0)
    assert.is_true(State.pause(20 * 1000))
    assert.equals(State.PHASE.PAUSED, State.current.phase)
    assert.equals(40 * 1000, State.current.remaining_ms)

    local ok, prev, remaining = State.resume(100 * 1000)
    assert.is_true(ok)
    assert.equals(State.PHASE.WORK, prev)
    assert.equals(40 * 1000, remaining)
    assert.equals(State.PHASE.WORK, State.current.phase)
    assert.equals(100 * 1000 + 40 * 1000, State.current.ends_at)
  end)

  it("pause does nothing when idle", function()
    assert.is_false(State.pause())
  end)

  it("resume does nothing when not paused", function()
    State.set_phase(State.PHASE.WORK, 1000, 0)
    local ok = State.resume()
    assert.is_false(ok)
  end)

  it("keeps duration_ms through pause/resume and clears it on idle", function()
    State.set_phase(State.PHASE.WORK, 60 * 1000, 0)
    assert.equals(60 * 1000, State.current.duration_ms)
    State.pause(20 * 1000)
    assert.equals(60 * 1000, State.current.duration_ms)
    State.resume(30 * 1000)
    assert.equals(60 * 1000, State.current.duration_ms)
    State.set_phase(State.PHASE.IDLE, 0)
    assert.is_nil(State.current.duration_ms)
  end)

  it("reset returns to idle", function()
    State.set_phase(State.PHASE.WORK, 1000, 0)
    State.current.cycle_index = 3
    State.reset()
    assert.equals(State.PHASE.IDLE, State.current.phase)
    assert.equals(0, State.current.cycle_index)
  end)
end)
