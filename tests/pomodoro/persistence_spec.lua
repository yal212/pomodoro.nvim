---@diagnostic disable: undefined-field, duplicate-set-field, redundant-parameter
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

  it("merges another instance's writes instead of clobbering", function()
    local today = os.date("%Y-%m-%d")
    Stats.load()
    Stats.record_work_complete()
    -- Simulate a second instance writing its own counts to the same file.
    Persistence.save({
      version = 1,
      days = {
        [today] = { completed_work = 5, completed_long_breaks = 0, minutes_focused = 125 },
      },
    })
    Stats.record_work_complete()
    local on_disk = Persistence.load().days[today]
    assert.equals(6, on_disk.completed_work)
    assert.equals(150, on_disk.minutes_focused)
    -- In-memory view adopted the merged counts too.
    assert.equals(6, Stats.today().completed_work)
  end)

  it("merges long-break counts from another instance", function()
    local today = os.date("%Y-%m-%d")
    Stats.load()
    Persistence.save({
      version = 1,
      days = {
        [today] = { completed_work = 0, completed_long_breaks = 2, minutes_focused = 0 },
      },
    })
    Stats.record_long_break_complete()
    assert.equals(3, Persistence.load().days[today].completed_long_breaks)
  end)

  it("retains deltas when a save fails and applies them on the next save", function()
    local today = os.date("%Y-%m-%d")
    Stats.load()
    local real_save = Persistence.save
    Persistence.save = function()
      return false, "disk full"
    end
    local real_notify = vim.notify
    vim.notify = function() end
    Stats.record_work_complete()
    Persistence.save = real_save
    vim.notify = real_notify
    assert.is_nil(Persistence.load().days[today])
    Stats.save()
    -- The increment lands exactly once.
    assert.equals(1, Persistence.load().days[today].completed_work)
    Stats.save()
    assert.equals(1, Persistence.load().days[today].completed_work)
  end)

  it("reset overwrites disk even after an external write", function()
    local today = os.date("%Y-%m-%d")
    Stats.load()
    Persistence.save({
      version = 1,
      days = {
        [today] = { completed_work = 5, completed_long_breaks = 0, minutes_focused = 125 },
      },
    })
    Stats.reset()
    assert.same({}, Persistence.load().days)
  end)

  it("save with persistence disabled leaves the in-memory db intact", function()
    local today = os.date("%Y-%m-%d")
    Config.merge({ persistence = { enabled = false } })
    Stats._db = {
      version = 1,
      days = {
        [today] = { completed_work = 4, completed_long_breaks = 1, minutes_focused = 100 },
      },
    }
    Stats.save()
    assert.equals(4, Stats.today().completed_work)
  end)
end)
