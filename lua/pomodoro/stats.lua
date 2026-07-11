local Persistence = require("pomodoro.persistence")
local Config = require("pomodoro.config")

local M = {}

M._db = nil

-- Increments not yet persisted, keyed like `_db.days`. Saves re-read the file
-- and apply these on top, so concurrent Neovim instances don't clobber each
-- other's same-day counts.
M._pending = {}

-- Calendar-day key for `days_ago` days before `now`. os.time() normalizes
-- out-of-range fields, so the arithmetic is DST-safe — subtracting fixed
-- 86400s chunks skips or repeats a date around DST transitions.
local function day_key(days_ago, now)
  local t = os.date("*t", now)
  return os.date(
    "%Y-%m-%d",
    os.time({ year = t.year, month = t.month, day = t.day - days_ago, hour = 12 })
  )
end

local function today_key()
  return day_key(0)
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

local function bump(key, field, amount)
  M._pending[key] = M._pending[key]
    or {
      completed_work = 0,
      completed_long_breaks = 0,
      minutes_focused = 0,
    }
  M._pending[key][field] = M._pending[key][field] + amount
end

function M.load()
  M._db = Persistence.load()
  M._pending = {}
  return M._db
end

function M.db()
  if not M._db then
    M.load()
  end
  return M._db
end

local function notify_save_failed(err)
  vim.notify(
    "pomodoro: failed to save stats: " .. (err or "unknown error"),
    vim.log.levels.WARN,
    { title = "Pomodoro" }
  )
end

function M.save()
  if not M._db or not Config.get().persistence.enabled then
    return
  end
  -- Read-merge-write: re-read the file and apply only our pending deltas on
  -- top, so another instance's same-day counts survive this save.
  local merged = Persistence.load()
  for key, delta in pairs(M._pending) do
    local day = ensure_day(merged, key)
    day.completed_work = day.completed_work + delta.completed_work
    day.completed_long_breaks = day.completed_long_breaks + delta.completed_long_breaks
    day.minutes_focused = day.minutes_focused + delta.minutes_focused
  end
  local ok, err = Persistence.save(merged)
  if ok then
    M._db = merged
    M._pending = {}
  else
    -- Deltas stay pending and retry on the next save.
    notify_save_failed(err)
  end
end

--- @param minutes number|nil actual block length; defaults to the configured
---   work duration
function M.record_work_complete(minutes)
  local db = M.db()
  local key = today_key()
  local day = ensure_day(db, key)
  local focused = minutes or Config.get().durations.work
  day.completed_work = day.completed_work + 1
  day.minutes_focused = day.minutes_focused + focused
  bump(key, "completed_work", 1)
  bump(key, "minutes_focused", focused)
  M.save()
end

function M.record_long_break_complete()
  local db = M.db()
  local key = today_key()
  local day = ensure_day(db, key)
  day.completed_long_breaks = day.completed_long_breaks + 1
  bump(key, "completed_long_breaks", 1)
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
    local key = day_key(i)
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
    local d = db.days[day_key(days_ago)]
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
  -- Overwrite rather than merge: a merge would re-read the file and
  -- resurrect the data the user just wiped.
  M._db = Persistence.empty_db()
  M._pending = {}
  local ok, err = Persistence.save(M._db)
  if not ok then
    notify_save_failed(err)
  end
end

M._day_key = day_key

return M
