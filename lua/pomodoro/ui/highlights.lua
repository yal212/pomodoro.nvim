local State = require("pomodoro.state")

local M = {}

function M.ensure_highlights()
  local groups = {
    PomodoroWork = "DiagnosticWarn",
    PomodoroBreak = "DiagnosticOk",
    PomodoroPaused = "DiagnosticHint",
    PomodoroIdle = "Comment",
    PomodoroProgress = "DiagnosticInfo",
    PomodoroProgressTrack = "NonText",
    PomodoroDim = "Comment",
    PomodoroDimNC = "Comment",
    PomodoroTitle = "FloatTitle",
  }
  for name, link in pairs(groups) do
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
end

function M.phase_hl(phase)
  if phase == State.PHASE.WORK then
    return "PomodoroWork"
  elseif phase == State.PHASE.SHORT_BREAK or phase == State.PHASE.LONG_BREAK then
    return "PomodoroBreak"
  elseif phase == State.PHASE.PAUSED then
    return "PomodoroPaused"
  end
  return "PomodoroIdle"
end

return M
