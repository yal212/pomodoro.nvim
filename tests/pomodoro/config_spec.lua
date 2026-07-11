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

  it("rejects wrong duration types", function()
    assert.has_error(function()
      Config.merge({ durations = { work = "x" } })
    end)
  end)

  it("validates daily_goal", function()
    assert.has_error(function()
      Config.merge({ daily_goal = -1 })
    end)
    assert.has_error(function()
      Config.merge({ daily_goal = "four" })
    end)
    Config.merge({ daily_goal = 4 })
    assert.equals(4, Config.get().daily_goal)
  end)

  it("requires statusline.condition to be a function", function()
    assert.has_error(function()
      Config.merge({ statusline = { condition = 5 } })
    end)
    Config.merge({
      statusline = {
        condition = function()
          return true
        end,
      },
    })
  end)

  it("validates notify.float_duration_ms", function()
    assert.has_error(function()
      Config.merge({ notify = { float_duration_ms = 0 } })
    end)
    assert.has_error(function()
      Config.merge({ notify = { float_duration_ms = "4s" } })
    end)
    Config.merge({ notify = { float_duration_ms = 2000 } })
    assert.equals(2000, Config.get().notify.float_duration_ms)
  end)

  it("validates statusline.format", function()
    assert.has_error(function()
      Config.merge({ statusline = { format = 5 } })
    end)
    assert.has_error(function()
      Config.merge({ statusline = { format = "%d" } })
    end)
    Config.merge({ statusline = { format = "[%s|%s]" } })
    Config.merge({ statusline = { format = "%s" } })
  end)

  it("validates statusline.refresh_ms", function()
    assert.has_error(function()
      Config.merge({ statusline = { refresh_ms = -1 } })
    end)
    -- 0 disables the redraw loop and stays legal
    Config.merge({ statusline = { refresh_ms = 0 } })
  end)

  it("validates status_window dimensions and offsets", function()
    assert.has_error(function()
      Config.merge({ status_window = { width = 0 } })
    end)
    assert.has_error(function()
      Config.merge({ status_window = { height = "tall" } })
    end)
    assert.has_error(function()
      Config.merge({ status_window = { row = -1 } })
    end)
    assert.has_error(function()
      Config.merge({ status_window = { refresh_ms = 0 } })
    end)
  end)

  it("validates status_window enums and border", function()
    assert.error_matches(function()
      Config.merge({ status_window = { anchor = "TOP" } })
    end, "unknown anchor")
    assert.has_error(function()
      Config.merge({ status_window = { border = 3 } })
    end)
    assert.has_error(function()
      Config.merge({ status_window = { title_pos = "middle" } })
    end)
    assert.has_error(function()
      Config.merge({ status_window = { icons = { work = 5 } } })
    end)
    Config.merge({
      status_window = {
        border = { "╔", "═", "╗", "║", "╝", "═", "╚", "║" },
        anchor = "SW",
        icons = { work = "W" },
      },
    })
    assert.equals("SW", Config.get().status_window.anchor)
  end)

  it("validates persistence options", function()
    assert.has_error(function()
      Config.merge({ persistence = { path = 5 } })
    end)
    assert.has_error(function()
      Config.merge({ persistence = { enabled = "yes" } })
    end)
    Config.merge({ persistence = { enabled = false, path = "/tmp/stats.json" } })
  end)

  it("validates focus.blocked_commands", function()
    assert.has_error(function()
      Config.merge({ focus = { blocked_commands = "Lazy" } })
    end)
    assert.has_error(function()
      Config.merge({ focus = { blocked_commands = { "Lazy", 5 } } })
    end)
    assert.has_error(function()
      Config.merge({ focus = { enabled = "on" } })
    end)
    Config.merge({ focus = { blocked_commands = { "Lazy", "Mason" } } })
  end)

  it("accepts a full valid config", function()
    Config.merge({
      durations = { work = 50, short_break = 10, long_break = 30 },
      cycles_per_long_break = 3,
      daily_goal = 8,
      notify_styles = { "vim_notify" },
      notify = { float_duration_ms = 2500 },
      statusline = { icon = "P", show_when_idle = true, format = "%s %s", refresh_ms = 500 },
      status_window = {
        border = "rounded",
        width = 40,
        height = 6,
        anchor = "NE",
        row = 0,
        col_offset = 1,
        refresh_ms = 500,
        show_progress_bar = true,
        show_today = false,
        title = " pomodoro ",
        title_pos = "left",
        icons = { work = "▶", idle = "○" },
      },
      persistence = { enabled = true, path = "/tmp/pomodoro-stats.json" },
      focus = { enabled = true, blocked_commands = { "Lazy" }, dim_inactive = true },
      hooks = { on_work_start = function() end },
    })
    assert.equals(50, Config.get().durations.work)
    assert.equals(8, Config.get().daily_goal)
    assert.equals(40, Config.get().status_window.width)
  end)
end)
