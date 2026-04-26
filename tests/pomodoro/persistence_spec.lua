---@diagnostic disable: undefined-field
describe("persistence", function()
  local Persistence, Config, Stats
  local tmpdir, statspath

  before_each(function()
    tmpdir = vim.fn.tempname() .. "_pomodoro"
    vim.fn.mkdir(tmpdir, "p")
    statspath = tmpdir .. "/stats.json"
    package.loaded["pomodoro.config"] = nil
    package.loaded["pomodoro.persistence"] = nil
    package.loaded["pomodoro.stats"] = nil
    Config = require("pomodoro.config")
    Persistence = require("pomodoro.persistence")
    Stats = require("pomodoro.stats")
    Config.merge({ persistence = { path = statspath } })
  end)

  after_each(function()
    vim.fn.delete(tmpdir, "rf")
  end)

  it("returns empty db when file missing", function()
    local db = Persistence.load()
    assert.same({ version = 1, days = {} }, db)
  end)

  it("round-trips JSON", function()
    local db = {
      version = 1,
      days = {
        ["2026-04-26"] = { completed_work = 3, completed_long_breaks = 0, minutes_focused = 75 },
      },
    }
    assert.is_true((Persistence.save(db)))
    local loaded = Persistence.load()
    assert.equals(3, loaded.days["2026-04-26"].completed_work)
    assert.equals(75, loaded.days["2026-04-26"].minutes_focused)
  end)

  it("falls back to empty db on corrupt JSON", function()
    local fd = assert(io.open(statspath, "w"))
    fd:write("{not json")
    fd:close()
    local db = Persistence.load()
    assert.same({}, db.days)
    -- corrupt file moved aside
    assert.equals(1, vim.fn.filereadable(statspath .. ".bak"))
  end)

  it("atomic write leaves no .tmp behind", function()
    Persistence.save({
      version = 1,
      days = { foo = { completed_work = 1, completed_long_breaks = 0, minutes_focused = 25 } },
    })
    assert.equals(0, vim.fn.filereadable(statspath .. ".tmp"))
    assert.equals(1, vim.fn.filereadable(statspath))
  end)

  it("stats.record_work_complete increments today's count", function()
    Stats.load()
    Stats.record_work_complete()
    local today = Stats.today()
    assert.equals(1, today.completed_work)
    assert.equals(25, today.minutes_focused)
  end)
end)
