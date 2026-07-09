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
    local ok, err = Persistence.save(M._db)
    if not ok then
      vim.notify(
        "pomodoro: failed to save stats: " .. (err or "unknown error"),
        vim.log.levels.WARN,
        { title = "Pomodoro" }
      )
    end
  end
end

--- @param minutes number|nil actual block length; defaults to the configured
---   work duration
function M.record_work_complete(minutes)
  local db = M.db()
  local day = ensure_day(db, today_key())
  day.completed_work = day.completed_work + 1
  day.minutes_focused = day.minutes_focused + (minutes or Config.get().durations.work)
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

--- Current streak in days: consecutive days meeting daily_goal (or >= 1
--- completed block when no goal is set), counted back from yesterday.
--- Today extends the streak once it qualifies, but a zero today doesn't
--- break a streak that ran through yesterday.
function M.streak(goal)
  local threshold = (goal and goal > 0) and goal or 1
  local db = M.db()
  local function meets(days_ago)
    local key = os.date("%Y-%m-%d", os.time() - days_ago * 86400)
    local d = db.days[key]
    return d ~= nil and d.completed_work >= threshold
  end
  local n = 0
  for i = 1, 3650 do
    if not meets(i) then
      break
    end
    n = n + 1
  end
  if meets(0) then
    n = n + 1
  end
  return n
end

function M.reset()
  M._db = Persistence.empty_db()
  M.save()
end

return M
