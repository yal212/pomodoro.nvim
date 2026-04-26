local State = require("pomodoro.state")

local M = {}

function M.next_after_work(cycle_index, cycles_per_long_break)
  if cycle_index > 0 and cycle_index % cycles_per_long_break == 0 then
    return State.PHASE.LONG_BREAK
  end
  return State.PHASE.SHORT_BREAK
end

function M.label(phase)
  if phase == State.PHASE.WORK then
    return "Work"
  elseif phase == State.PHASE.SHORT_BREAK then
    return "Short Break"
  elseif phase == State.PHASE.LONG_BREAK then
    return "Long Break"
  elseif phase == State.PHASE.PAUSED then
    return "Paused"
  end
  return "Idle"
end

function M.duration_ms(phase, durations)
  local minutes
  if phase == State.PHASE.WORK then
    minutes = durations.work
  elseif phase == State.PHASE.SHORT_BREAK then
    minutes = durations.short_break
  elseif phase == State.PHASE.LONG_BREAK then
    minutes = durations.long_break
  else
    return 0
  end
  return math.floor(minutes * 60 * 1000)
end

return M
