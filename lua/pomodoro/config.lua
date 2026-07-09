local M = {}

M.defaults = {
  durations = {
    work = 25,
    short_break = 5,
    long_break = 15,
  },
  cycles_per_long_break = 4,
  daily_goal = 0,
  auto_start_break = true,
  auto_start_work = false,
  notify_styles = { "vim_notify", "float" },
  notify = {
    float_duration_ms = 4000,
  },
  statusline = {
    icon = "",
    show_when_idle = false,
    format = "%s %s",
    refresh_ms = 250,
    condition = nil,
  },
  status_window = {
    border = "none",
    width = 36,
    height = 5,
    anchor = "NE",
    row = 1,
    col_offset = 2,
    refresh_ms = 250,
    show_progress_bar = true,
    show_today = true,
    icons = {
      work = "▶",
      short_break = "•",
      long_break = "★",
      paused = "❚❚",
      idle = "○",
    },
  },
  focus = {
    enabled = false,
    blocked_commands = {},
    silent_diagnostics = false,
    dim_inactive = false,
  },
  persistence = {
    enabled = true,
    path = nil,
  },
  hooks = {
    on_work_start = nil,
    on_work_end = nil,
    on_break_start = nil,
    on_break_end = nil,
    on_cycle_complete = nil,
  },
}

M.options = vim.deepcopy(M.defaults)

local function validate(opts)
  vim.validate({ opts = { opts, "table", true } })
  if not opts then
    return
  end
  if opts.durations then
    vim.validate({
      ["durations.work"] = { opts.durations.work, "number", true },
      ["durations.short_break"] = { opts.durations.short_break, "number", true },
      ["durations.long_break"] = { opts.durations.long_break, "number", true },
    })
    for k, v in pairs(opts.durations) do
      if type(v) == "number" and v <= 0 then
        error(("pomodoro: durations.%s must be > 0 (got %s)"):format(k, tostring(v)), 2)
      end
    end
  end
  if opts.cycles_per_long_break ~= nil then
    vim.validate({ cycles_per_long_break = { opts.cycles_per_long_break, "number" } })
    if opts.cycles_per_long_break < 1 then
      error("pomodoro: cycles_per_long_break must be >= 1", 2)
    end
  end
  if opts.daily_goal ~= nil then
    vim.validate({ daily_goal = { opts.daily_goal, "number" } })
    if opts.daily_goal < 0 then
      error("pomodoro: daily_goal must be >= 0", 2)
    end
  end
  if opts.notify_styles then
    vim.validate({ notify_styles = { opts.notify_styles, "table" } })
    for _, style in ipairs(opts.notify_styles) do
      if style ~= "vim_notify" and style ~= "float" then
        error(("pomodoro: unknown notify style %q (use vim_notify or float)"):format(style), 2)
      end
    end
  end
  if opts.hooks then
    for name, fn in pairs(opts.hooks) do
      if fn ~= nil and type(fn) ~= "function" then
        error(("pomodoro: hooks.%s must be a function"):format(name), 2)
      end
    end
  end
  if opts.statusline and opts.statusline.condition ~= nil then
    if type(opts.statusline.condition) ~= "function" then
      error("pomodoro: statusline.condition must be a function", 2)
    end
  end
end

function M.merge(user_opts)
  validate(user_opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user_opts or {})
  return M.options
end

function M.get()
  return M.options
end

return M
