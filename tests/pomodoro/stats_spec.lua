---@diagnostic disable: undefined-field
describe("stats", function()
  local Stats

  local function day(completed_work)
    return {
      completed_work = completed_work,
      completed_long_breaks = 0,
      minutes_focused = completed_work * 25,
    }
  end

  before_each(function()
    package.loaded["pomodoro.config"] = nil
    package.loaded["pomodoro.persistence"] = nil
    package.loaded["pomodoro.stats"] = nil
    require("pomodoro.config").merge({ persistence = { enabled = false } })
    Stats = require("pomodoro.stats")
  end)

  it("today is empty for a fresh db", function()
    assert.equals(0, Stats.today().completed_work)
  end)

  it("today reflects previously persisted counts", function()
    Stats._db = { version = 1, days = { [os.date("%Y-%m-%d")] = day(3) } }
    assert.equals(3, Stats.today().completed_work)
  end)

  it("record_work_complete builds on the persisted count", function()
    Stats._db = { version = 1, days = { [os.date("%Y-%m-%d")] = day(3) } }
    Stats.record_work_complete()
    assert.equals(4, Stats.today().completed_work)
  end)

  it("last_n_days is oldest-first, ends today, and fills gaps", function()
    local today = os.date("%Y-%m-%d")
    local two_ago = os.date("%Y-%m-%d", os.time() - 2 * 86400)
    Stats._db = { version = 1, days = { [today] = day(2), [two_ago] = day(5) } }
    local rows = Stats.last_n_days(3)
    assert.equals(3, #rows)
    assert.equals(two_ago, rows[1].date)
    assert.equals(today, rows[3].date)
    assert.equals(5, rows[1].data.completed_work)
    assert.equals(0, rows[2].data.completed_work) -- gap day filled with zeros
    assert.equals(2, rows[3].data.completed_work)
  end)

  describe("streak", function()
    local function key(days_ago)
      return os.date("%Y-%m-%d", os.time() - days_ago * 86400)
    end

    it("is 0 for an empty db", function()
      assert.equals(0, Stats.streak(0))
    end)

    it("counts consecutive days with any work when no goal is set", function()
      Stats._db = {
        version = 1,
        days = { [key(0)] = day(1), [key(1)] = day(2), [key(2)] = day(1) },
      }
      assert.equals(3, Stats.streak(0))
    end)

    it("a gap breaks the streak", function()
      Stats._db = {
        version = 1,
        days = { [key(1)] = day(2), [key(3)] = day(4) },
      }
      assert.equals(1, Stats.streak(0))
    end)

    it("a zero today preserves a streak through yesterday", function()
      Stats._db = {
        version = 1,
        days = { [key(1)] = day(2), [key(2)] = day(1) },
      }
      assert.equals(2, Stats.streak(0))
    end)

    it("applies the daily goal as the threshold", function()
      Stats._db = {
        version = 1,
        days = { [key(1)] = day(4), [key(2)] = day(3), [key(3)] = day(5) },
      }
      -- day(2) misses the goal of 4, so only yesterday counts
      assert.equals(1, Stats.streak(4))
    end)
  end)
end)
