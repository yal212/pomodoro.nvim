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
end)
