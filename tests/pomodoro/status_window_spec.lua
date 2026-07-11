---@diagnostic disable: undefined-field
describe("status window", function()
  local Config = require("pomodoro.config")
  local State = require("pomodoro.state")
  local Stats = require("pomodoro.stats")
  local Status = require("pomodoro.ui.status")

  local FILL = "█"
  local TRACK = "░"

  local function count(line, glyph)
    return select(2, line:gsub(glyph, ""))
  end

  -- Deterministic paused snapshot: remaining/duration are read from
  -- State.current directly, no clock involved.
  local function paused_work(remaining_ms, duration_ms)
    local now = vim.uv.now()
    State.set_phase(State.PHASE.WORK, duration_ms, now)
    State.pause(now + (duration_ms - remaining_ms))
  end

  before_each(function()
    Config.merge({ persistence = { enabled = false } })
    State.reset()
    Stats._db = nil
  end)

  after_each(function()
    Status.close()
  end)

  describe("build", function()
    it("renders the idle card", function()
      local lines, hls = Status._build()
      assert.equals(Config.get().status_window.height, #lines)
      assert.truthy(lines[1]:find("Idle", 1, true))
      assert.truthy(lines[3]:find(":Pomodoro start", 1, true))
      assert.equals("PomodoroIdle", hls[1].hl)
    end)

    it("fills the progress bar to 50%", function()
      paused_work(50000, 100000)
      local lines, hls = Status._build()
      -- width 36 -> 34 bar cells -> 17 filled at 50%
      local bar = lines[3]
      assert.equals(17, count(bar, FILL))
      assert.equals(17, count(bar, TRACK))
      local fill_hl, track_hl
      for _, h in ipairs(hls) do
        if h.hl == "PomodoroProgress" then
          fill_hl = h
        elseif h.hl == "PomodoroProgressTrack" then
          track_hl = h
        end
      end
      assert.equals(1, fill_hl.col_start)
      assert.equals(1 + 17 * #FILL, fill_hl.col_end)
      assert.equals(1 + 17 * #FILL, track_hl.col_start)
      assert.equals(1 + 34 * #FILL, track_hl.col_end)
    end)

    it("shows an empty bar at the start and a full bar at the end", function()
      paused_work(100000, 100000)
      local lines = Status._build()
      assert.equals(0, count(lines[3], FILL))
      assert.equals(34, count(lines[3], TRACK))

      State.reset()
      paused_work(0, 100000)
      lines = Status._build()
      assert.equals(34, count(lines[3], FILL))
      assert.equals(0, count(lines[3], TRACK))
    end)

    it("does not crash on a zero-length phase", function()
      State.set_phase(State.PHASE.WORK, 0, vim.uv.now())
      local lines = Status._build()
      assert.equals(0, count(lines[3], FILL))
    end)

    it("shows goal progress on the today line", function()
      Config.merge({ daily_goal = 8, persistence = { enabled = false } })
      Stats._db = {
        version = 1,
        days = {
          [os.date("%Y-%m-%d")] = {
            completed_work = 4,
            completed_long_breaks = 0,
            minutes_focused = 100,
          },
        },
      }
      paused_work(50000, 100000)
      local lines = Status._build()
      local last = lines[#lines]
      assert.truthy(last:find("today: 4 / 8 (50%)", 1, true))
    end)

    it("shows a plain count without a goal", function()
      Stats._db = {
        version = 1,
        days = {
          [os.date("%Y-%m-%d")] = {
            completed_work = 4,
            completed_long_breaks = 0,
            minutes_focused = 100,
          },
        },
      }
      paused_work(50000, 100000)
      local last = Status._build()[Config.get().status_window.height]
      assert.truthy(last:find("today: 4", 1, true))
      assert.is_nil(last:find("/", 1, true))
    end)

    it("always emits exactly the configured height", function()
      for _, opts in ipairs({
        { status_window = { height = 3 } },
        { status_window = { height = 9, show_today = false } },
        { status_window = { height = 5, show_progress_bar = false } },
      }) do
        opts.persistence = { enabled = false }
        Config.merge(opts)
        State.reset()
        paused_work(50000, 100000)
        assert.equals(opts.status_window.height, #Status._build())
        State.reset()
        assert.equals(opts.status_window.height, #Status._build())
      end
    end)
  end)

  describe("window", function()
    it("opens, renders, and toggles closed", function()
      Config.merge({ persistence = { enabled = false } })
      Status.open()
      assert.is_true(Status.is_open())
      local buf
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(w).relative == "editor" then
          buf = vim.api.nvim_win_get_buf(w)
        end
      end
      assert.equals(Config.get().status_window.height, vim.api.nvim_buf_line_count(buf))
      assert.is_false(vim.bo[buf].modifiable)
      Status.toggle()
      assert.is_false(Status.is_open())
    end)

    it("refresh on a closed window is a no-op", function()
      assert.is_false(Status.is_open())
      Status.refresh()
    end)
  end)
end)
