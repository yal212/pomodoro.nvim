---@diagnostic disable: undefined-field
describe("cycle", function()
  local Cycle, State

  before_each(function()
    package.loaded["pomodoro.cycle"] = nil
    package.loaded["pomodoro.state"] = nil
    State = require("pomodoro.state")
    Cycle = require("pomodoro.cycle")
  end)

  it("returns short_break for cycles 1..N-1", function()
    for i = 1, 3 do
      assert.equals(State.PHASE.SHORT_BREAK, Cycle.next_after_work(i, 4))
    end
  end)

  it("returns long_break exactly on Nth cycle", function()
    assert.equals(State.PHASE.LONG_BREAK, Cycle.next_after_work(4, 4))
    assert.equals(State.PHASE.LONG_BREAK, Cycle.next_after_work(8, 4))
  end)

  it("respects custom cycles_per_long_break", function()
    assert.equals(State.PHASE.SHORT_BREAK, Cycle.next_after_work(1, 2))
    assert.equals(State.PHASE.LONG_BREAK, Cycle.next_after_work(2, 2))
  end)

  it("computes durations in ms", function()
    local d = { work = 25, short_break = 5, long_break = 15 }
    assert.equals(25 * 60 * 1000, Cycle.duration_ms(State.PHASE.WORK, d))
    assert.equals(5 * 60 * 1000, Cycle.duration_ms(State.PHASE.SHORT_BREAK, d))
    assert.equals(15 * 60 * 1000, Cycle.duration_ms(State.PHASE.LONG_BREAK, d))
    assert.equals(0, Cycle.duration_ms(State.PHASE.IDLE, d))
  end)

  it("labels each phase", function()
    assert.equals("Work", Cycle.label(State.PHASE.WORK))
    assert.equals("Short Break", Cycle.label(State.PHASE.SHORT_BREAK))
    assert.equals("Long Break", Cycle.label(State.PHASE.LONG_BREAK))
    assert.equals("Paused", Cycle.label(State.PHASE.PAUSED))
    assert.equals("Idle", Cycle.label(State.PHASE.IDLE))
  end)
end)
