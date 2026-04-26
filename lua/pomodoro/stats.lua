local Persistence = require("pomodoro.persistence")
local Config = require("pomodoro.config")

local M = {}

M._db = nil

local function today_key()
  return os.date("%Y-%m-%d")
end

local function ensure_day(db, key)
  db.days[key] = db.days[key]
    or {
      completed_work = 0,
      completed_long_breaks = 0,
      minutes_focused = 0,
    }
  return db.days[key]
end

function M.load()
  M._db = Persistence.load()
  return M._db
end

function M.db()
  if not M._db then
    M.load()
  end
  return M._db
end

function M.save()
  if M._db then
    Persistence.save(M._db)
  end
end

function M.record_work_complete()
  local db = M.db()
  local day = ensure_day(db, today_key())
  day.completed_work = day.completed_work + 1
  day.minutes_focused = day.minutes_focused + Config.get().durations.work
  M.save()
end

function M.record_long_break_complete()
  local db = M.db()
  local day = ensure_day(db, today_key())
  day.completed_long_breaks = day.completed_long_breaks + 1
  M.save()
end

function M.today()
  local db = M.db()
  return db.days[today_key()]
    or { completed_work = 0, completed_long_breaks = 0, minutes_focused = 0 }
end

function M.last_n_days(n)
  local out = {}
  for i = n - 1, 0, -1 do
    local key = os.date("%Y-%m-%d", os.time() - i * 86400)
    out[#out + 1] = {
      date = key,
      data = M.db().days[key]
        or { completed_work = 0, completed_long_breaks = 0, minutes_focused = 0 },
    }
  end
  return out
end

function M.reset()
  M._db = Persistence.empty_db()
  M.save()
end

return M
