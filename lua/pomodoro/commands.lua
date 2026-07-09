local M = {}

local function pomodoro()
  return require("pomodoro")
end

function M.register()
  local user_cmd = vim.api.nvim_create_user_command

  user_cmd("PomodoroStart", function(opts)
    pomodoro().start(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    complete = function()
      return { "work", "short", "long" }
    end,
    desc = "Start a pomodoro phase",
  })

  user_cmd("PomodoroPause", function()
    pomodoro().pause()
  end, { desc = "Pause the active pomodoro" })

  user_cmd("PomodoroResume", function()
    pomodoro().resume()
  end, { desc = "Resume a paused pomodoro" })

  user_cmd("PomodoroStop", function()
    pomodoro().stop()
  end, { desc = "Stop the active pomodoro" })

  user_cmd("PomodoroSkip", function()
    pomodoro().skip()
  end, { desc = "Skip the current phase" })

  user_cmd("PomodoroRestart", function()
    pomodoro().restart()
  end, { desc = "Restart the current phase from the beginning" })

  user_cmd("PomodoroStatus", function()
    pomodoro().status()
  end, { desc = "Toggle the pomodoro status window" })

  user_cmd("PomodoroStats", function()
    pomodoro().stats_summary()
  end, { desc = "Print today + last 7 days summary" })

  user_cmd("PomodoroReset", function()
    vim.ui.select({ "yes", "no" }, { prompt = "Wipe all pomodoro stats?" }, function(choice)
      if choice == "yes" then
        pomodoro().reset_stats()
      end
    end)
  end, { desc = "Wipe persisted pomodoro stats" })

  pcall(function()
    require("pomodoro.telescope").register()
  end)
end

return M
