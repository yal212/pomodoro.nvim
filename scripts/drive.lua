-- End-to-end drive of pomodoro.nvim through its user command: real timers
-- (3-second phases), real :Pomodoro subcommands, assertions on observable
-- state. Complements the unit suite by exercising the seams the specs mock.
-- Run from the repo root:
--   nvim --headless --clean -u NONE -l scripts/drive.lua
-- Exits non-zero if any step fails.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd("runtime plugin/pomodoro.lua")

local results = {}
local function step(name, fn)
  local ok, err = pcall(fn)
  results[#results + 1] = (ok and "OK  " or "FAIL")
    .. " "
    .. name
    .. (ok and "" or (" -- " .. tostring(err)))
end
local function eq(a, b, msg)
  if a ~= b then
    error(("%s: expected %s, got %s"):format(msg or "eq", vim.inspect(b), vim.inspect(a)), 2)
  end
end

-- capture notifications
local notes = {}
vim.notify = function(msg, ...)
  notes[#notes + 1] = tostring(msg)
end

-- headless vim.ui.select blocks on inputlist(); auto-answer "Stop"
vim.ui.select = function(_, _, on_choice)
  on_choice("Stop")
end

local stats_path = vim.fn.tempname() .. "/stats.json"
local hook_log = {}
require("pomodoro").setup({
  durations = { work = 0.05, short_break = 0.05, long_break = 0.05 }, -- 3s phases
  cycles_per_long_break = 2,
  daily_goal = 4,
  notify_styles = { "vim_notify" },
  auto_start_break = true,
  auto_start_work = false,
  persistence = { enabled = true, path = stats_path },
  focus = { enabled = true, dim_inactive = true },
  hooks = {
    on_work_end = function()
      hook_log[#hook_log + 1] = "work_end"
    end,
    on_break_end = function()
      hook_log[#hook_log + 1] = "break_end"
    end,
  },
})

local State = require("pomodoro.state")
local Stats = require("pomodoro.stats")

step("old :PomodoroStart command is gone", function()
  eq(vim.fn.exists(":PomodoroStart"), 0, "old command still defined")
end)

step("start work via :Pomodoro Start (case-insensitive)", function()
  vim.cmd("Pomodoro Start")
  eq(State.current.phase, State.PHASE.WORK, "phase")
  eq(State.current.duration_ms, 3000, "duration_ms")
end)

step("dim_inactive sets winhighlight on splits", function()
  vim.cmd("split")
  local wh = vim.wo[vim.api.nvim_get_current_win()].winhighlight
  assert(wh:find("PomodoroDimNC", 1, true), "new split not dimmed: " .. wh)
end)

step("natural completion -> stats + auto short break + undim", function()
  vim.wait(5000, function()
    return State.current.phase == State.PHASE.SHORT_BREAK
  end, 50)
  eq(State.current.phase, State.PHASE.SHORT_BREAK, "phase after work")
  eq(Stats.today().completed_work, 1, "completed_work")
  eq(hook_log[1], "work_end", "on_work_end fired")
  local wh = vim.wo[vim.api.nvim_get_current_win()].winhighlight
  assert(not wh:find("PomodoroDimNC", 1, true), "still dimmed after work end: " .. wh)
end)

step("skip during break -> no break_end hook", function()
  local hooks_before = #hook_log
  vim.cmd("Pomodoro skip")
  eq(#hook_log, hooks_before, "hook count unchanged")
  -- auto_start_work=false -> idle + prompt suppressed headless (vim.ui.select)
end)

step("custom duration :Pomodoro start 0.1 (6s) doesn't touch config", function()
  vim.cmd("Pomodoro stop")
  vim.cmd("Pomodoro start 0.1")
  eq(State.current.phase, State.PHASE.WORK, "phase")
  eq(State.current.duration_ms, 6000, "override duration")
  eq(require("pomodoro.config").get().durations.work, 0.05, "config untouched")
end)

step("restart keeps the override", function()
  vim.cmd("Pomodoro restart")
  eq(State.current.duration_ms, 6000, "restarted duration")
end)

step("skip during work -> nothing recorded", function()
  local before = Stats.today().completed_work
  vim.cmd("Pomodoro skip")
  eq(Stats.today().completed_work, before, "completed_work unchanged by skip")
end)

step("pause/resume via commands", function()
  vim.cmd("Pomodoro stop")
  vim.cmd("Pomodoro start")
  vim.cmd("Pomodoro pause")
  eq(State.current.phase, State.PHASE.PAUSED, "paused")
  vim.cmd("Pomodoro resume")
  eq(State.current.phase, State.PHASE.WORK, "resumed")
  vim.cmd("Pomodoro stop")
end)

step(":Pomodoro stats mentions streak", function()
  notes = {}
  vim.cmd("Pomodoro stats")
  local out = table.concat(notes, "\n")
  assert(out:find("Streak:"), "no streak line in: " .. out)
  assert(out:find("Today: 1 work"), "wrong today count in: " .. out)
end)

step(":Pomodoro history opens a float with data + streak", function()
  vim.cmd("Pomodoro history 5")
  local float_buf
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative ~= "" then
      float_buf = vim.api.nvim_win_get_buf(w)
    end
  end
  assert(float_buf, "no float window found")
  local lines = table.concat(vim.api.nvim_buf_get_lines(float_buf, 0, -1, false), "\n")
  assert(lines:find("last 5 days"), "no header in: " .. lines)
  assert(lines:find("Streak:"), "no streak footer")
  assert(lines:find("1 work"), "today's count missing")
  vim.fn.feedkeys("q", "x") -- q closes the panel
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    assert(vim.api.nvim_win_get_config(w).relative == "", "float still open after q")
  end
end)

step("stats persisted to disk (restart survival)", function()
  require("pomodoro.stats").save()
  local data = table.concat(vim.fn.readfile(stats_path), "")
  local db = vim.json.decode(data)
  eq(db.days[os.date("%Y-%m-%d")].completed_work, 1, "persisted count")
end)

-- probes
step("probe: :Pomodoro start -5 rejected", function()
  notes = {}
  vim.cmd("Pomodoro start -5")
  eq(State.current.phase, State.PHASE.IDLE, "still idle")
  assert(table.concat(notes, " "):find("positive"), "no warning shown")
end)

step("probe: double start warns", function()
  vim.cmd("Pomodoro start")
  notes = {}
  vim.cmd("Pomodoro start")
  assert(table.concat(notes, " "):find("Already running"), "no already-running warning")
  vim.cmd("Pomodoro stop")
end)

step("probe: unknown subcommand shows usage", function()
  notes = {}
  vim.cmd("Pomodoro bogus")
  assert(table.concat(notes, " "):find("Usage: :Pomodoro"), "no usage message shown")
end)

step("probe: skip/restart when idle warn instead of erroring", function()
  notes = {}
  vim.cmd("Pomodoro skip")
  vim.cmd("Pomodoro restart")
  local out = table.concat(notes, " ")
  assert(out:find("Nothing to skip") and out:find("Nothing to restart"), out)
end)

step("probe: sound config validation rejects bad cmd", function()
  local ok = pcall(require("pomodoro.config").merge, { sound = { cmd = 42 } })
  eq(ok, false, "bad sound.cmd accepted")
end)

step("probe: checkhealth pomodoro runs", function()
  vim.cmd("checkhealth pomodoro")
  local out = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  assert(out:find("setup%(%) called"), "health missing setup ok: " .. out:sub(1, 200))
end)

print("\n=== DRIVE RESULTS ===")
local failed = false
for _, r in ipairs(results) do
  print(r)
  failed = failed or r:sub(1, 4) == "FAIL"
end
vim.cmd(failed and "cq!" or "qa!")
