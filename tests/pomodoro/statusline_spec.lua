---@diagnostic disable: undefined-field
describe("statusline", function()
  local Config = require("pomodoro.config")
  local State = require("pomodoro.state")
  local Statusline = require("pomodoro.statusline")

  before_each(function()
    Config.merge(nil)
    State.reset()
  end)

  after_each(function()
    Statusline.stop_redraw_loop()
  end)

  describe("format_remaining", function()
    it("formats mm:ss", function()
      assert.equals("01:30", Statusline.format_remaining(90 * 1000))
      assert.equals("00:00", Statusline.format_remaining(0))
      assert.equals("25:00", Statusline.format_remaining(25 * 60 * 1000))
    end)
  end)

  describe("component", function()
    it("is empty while idle by default", function()
      assert.equals("", Statusline.component())
    end)

    it("shows Idle when show_when_idle is set", function()
      Config.merge({ statusline = { show_when_idle = true } })
      local icon = Config.get().statusline.icon
      assert.equals(string.format("%s %s", icon, "Idle"), Statusline.component())
    end)

    it("shows the phase label and countdown while running", function()
      State.set_phase(State.PHASE.WORK, 25 * 60 * 1000, vim.uv.now())
      -- pattern-match: a tick may elapse between set_phase and render
      assert.truthy(Statusline.component():find("Work 2[45]:%d%d"))
    end)

    it("freezes the countdown while paused", function()
      local now = vim.uv.now()
      State.set_phase(State.PHASE.WORK, 25 * 60 * 1000, now)
      State.pause(now)
      local icon = Config.get().statusline.icon
      assert.equals(string.format("%s %s", icon, "Paused 25:00"), Statusline.component())
    end)

    it("applies a custom format", function()
      Config.merge({ statusline = { format = "[%s|%s]", show_when_idle = true } })
      local icon = Config.get().statusline.icon
      assert.equals(string.format("[%s|%s]", icon, "Idle"), Statusline.component())
    end)

    it("is hidden when condition returns false", function()
      Config.merge({
        statusline = {
          show_when_idle = true,
          condition = function()
            return false
          end,
        },
      })
      assert.equals("", Statusline.component())
    end)

    it("still renders when condition throws", function()
      Config.merge({
        statusline = {
          show_when_idle = true,
          condition = function()
            error("boom")
          end,
        },
      })
      assert.is_true(Statusline.component() ~= "")
    end)
  end)

  describe("component_lualine", function()
    it("returns text plus the phase highlight", function()
      State.set_phase(State.PHASE.WORK, 25 * 60 * 1000, vim.uv.now())
      local c = Statusline.component_lualine()
      assert.equals("PomodoroWork", c.hl)
      assert.truthy(c.text:find("Work", 1, true))
    end)

    it("uses the idle highlight when idle", function()
      assert.equals("PomodoroIdle", Statusline.component_lualine().hl)
    end)
  end)

  describe("redraw loop", function()
    it("start and stop are idempotent", function()
      Statusline.start_redraw_loop(10)
      Statusline.start_redraw_loop(10)
      Statusline.stop_redraw_loop()
      Statusline.stop_redraw_loop()
    end)

    it("does not start with a non-positive interval", function()
      Statusline.start_redraw_loop(0)
      Statusline.stop_redraw_loop()
      Statusline.start_redraw_loop(nil)
      Statusline.stop_redraw_loop()
    end)
  end)
end)
