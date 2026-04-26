---@diagnostic disable: undefined-field
describe("timer", function()
  local Timer

  before_each(function()
    package.loaded["pomodoro.timer"] = nil
    Timer = require("pomodoro.timer")
  end)

  after_each(function()
    Timer.stop()
  end)

  it("is_running false initially", function()
    assert.is_false(Timer.is_running())
  end)

  it("calls expiry callback after duration", function()
    local fired = false
    Timer.start(20, function()
      fired = true
    end)
    assert.is_true(Timer.is_running())
    -- vim.wait pumps the event loop
    vim.wait(200, function()
      return fired
    end, 5)
    assert.is_true(fired)
    assert.is_false(Timer.is_running())
  end)

  it("stop cancels pending callback", function()
    local fired = false
    Timer.start(50, function()
      fired = true
    end)
    Timer.stop()
    vim.wait(80, function()
      return false
    end, 10)
    assert.is_false(fired)
    assert.is_false(Timer.is_running())
  end)

  it("starting again replaces previous timer", function()
    local first, second = false, false
    Timer.start(40, function()
      first = true
    end)
    Timer.start(20, function()
      second = true
    end)
    vim.wait(200, function()
      return second
    end, 5)
    assert.is_true(second)
    assert.is_false(first)
  end)
end)
