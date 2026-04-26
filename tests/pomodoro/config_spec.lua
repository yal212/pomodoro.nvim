---@diagnostic disable: undefined-field
describe("config", function()
  local Config

  before_each(function()
    package.loaded["pomodoro.config"] = nil
    Config = require("pomodoro.config")
  end)

  it("returns defaults when no opts given", function()
    Config.merge(nil)
    assert.equals(25, Config.get().durations.work)
    assert.equals(4, Config.get().cycles_per_long_break)
  end)

  it("deep-merges nested opts", function()
    Config.merge({ durations = { work = 50 } })
    assert.equals(50, Config.get().durations.work)
    -- untouched keys preserved
    assert.equals(5, Config.get().durations.short_break)
    assert.equals(15, Config.get().durations.long_break)
  end)

  it("rejects non-positive durations", function()
    assert.has_error(function()
      Config.merge({ durations = { work = 0 } })
    end)
    assert.has_error(function()
      Config.merge({ durations = { work = -10 } })
    end)
  end)

  it("rejects unknown notify styles", function()
    assert.has_error(function()
      Config.merge({ notify_styles = { "telegram" } })
    end)
  end)

  it("rejects non-function hooks", function()
    assert.has_error(function()
      Config.merge({ hooks = { on_work_start = "nope" } })
    end)
  end)

  it("requires cycles_per_long_break >= 1", function()
    assert.has_error(function()
      Config.merge({ cycles_per_long_break = 0 })
    end)
  end)
end)
