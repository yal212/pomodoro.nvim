local M = {}

--- @class pomodoro.DurationsConfig
--- @field work? number work block length in minutes (default 25)
--- @field short_break? number short break length in minutes (default 5)
--- @field long_break? number long break length in minutes (default 15)

--- @class pomodoro.NotifyConfig
--- @field float_duration_ms? number how long the floating toast stays up (default 4000)

--- @class pomodoro.SoundConfig
--- @field enabled? boolean play a sound on natural phase end (default false)
--- @field cmd? string|string[] command string (run via `sh -c`) or argv table;
---   nil uses `afplay` with a system sound on macOS

--- @class pomodoro.StatuslineConfig
--- @field icon? string prefix icon (default "")
--- @field show_when_idle? boolean render the component while idle (default false)
--- @field format? string `string.format` pattern receiving icon, body (default "%s %s")
--- @field refresh_ms? number statusline redraw interval while running (default 250)
--- @field condition? fun(ctx: { phase: string, remaining_ms: number }): boolean
---   return false to hide the component

--- @class pomodoro.StatusWindowIcons
--- @field work? string
--- @field short_break? string
--- @field long_break? string
--- @field paused? string
--- @field idle? string

--- @class pomodoro.StatusWindowConfig
--- @field border? string|string[] window border (default "none")
--- @field width? number (default 36)
--- @field height? number (default 5)
--- @field anchor? string float anchor corner (default "NE")
--- @field row? number (default 1)
--- @field col_offset? number columns from the right edge (default 2)
--- @field refresh_ms? number redraw interval (default 250)
--- @field show_progress_bar? boolean (default true)
--- @field show_today? boolean show today's completed count (default true)
--- @field title? string optional float title (default nil)
--- @field title_pos? "left"|"center"|"right" title position when title is set (default "center")
--- @field icons? pomodoro.StatusWindowIcons

--- @class pomodoro.FocusConfig
--- @field enabled? boolean (default false)
--- @field blocked_commands? string[] Ex commands to block during work, e.g. { "Lazy" }
--- @field silent_diagnostics? boolean hide diagnostic virtual_text during work (default false)
--- @field dim_inactive? boolean dim non-current windows during work (default false)

--- @class pomodoro.PersistenceConfig
--- @field enabled? boolean persist per-day stats as JSON (default true)
--- @field path? string stats file location; nil = stdpath("data")/pomodoro/stats.json

--- @class pomodoro.HookPayload
--- @field duration_min? number
--- @field kind? "short"|"long"
--- @field cycle_index? number

--- @class pomodoro.HooksConfig
--- @field on_work_start? fun(payload: pomodoro.HookPayload)
--- @field on_work_end? fun(payload: pomodoro.HookPayload)
--- @field on_break_start? fun(payload: pomodoro.HookPayload)
--- @field on_break_end? fun(payload: pomodoro.HookPayload)
--- @field on_cycle_complete? fun(payload: pomodoro.HookPayload)

--- @class pomodoro.Config
--- @field durations? pomodoro.DurationsConfig phase lengths in minutes
--- @field cycles_per_long_break? number long break every Nth work block (default 4)
--- @field daily_goal? number target work blocks per day, 0 = disabled (default 0)
--- @field auto_start_break? boolean break begins as soon as work ends (default true)
--- @field auto_start_work? boolean next work block begins as soon as a break ends (default false)
--- @field notify_styles? ("vim_notify"|"float")[] notification channels, in display order
--- @field notify? pomodoro.NotifyConfig
--- @field sound? pomodoro.SoundConfig
--- @field statusline? pomodoro.StatuslineConfig
--- @field status_window? pomodoro.StatusWindowConfig
--- @field focus? pomodoro.FocusConfig
--- @field persistence? pomodoro.PersistenceConfig
--- @field hooks? pomodoro.HooksConfig

-- Deliberately not annotated as pomodoro.Config: the literal's inferred
-- (fully-present) type is what internal code should see after merging.
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
  sound = {
    enabled = false,
    cmd = nil, -- string (run via sh -c) or argv table; nil = platform default
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
    title = nil, -- optional float title, e.g. " pomodoro "
    title_pos = "center",
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

-- vim.validate's table form is deprecated on 0.11+ and its replacement
-- signature does not exist on 0.10, so use a local check instead.
local function check(name, value, expected, optional)
  if value == nil and optional then
    return
  end
  if type(value) ~= expected then
    error(("pomodoro: %s must be a %s (got %s)"):format(name, expected, type(value)), 3)
  end
end

local function validate(opts)
  check("opts", opts, "table", true)
  if not opts then
    return
  end
  if opts.durations then
    check("durations.work", opts.durations.work, "number", true)
    check("durations.short_break", opts.durations.short_break, "number", true)
    check("durations.long_break", opts.durations.long_break, "number", true)
    for k, v in pairs(opts.durations) do
      if type(v) == "number" and v <= 0 then
        error(("pomodoro: durations.%s must be > 0 (got %s)"):format(k, tostring(v)), 2)
      end
    end
  end
  if opts.cycles_per_long_break ~= nil then
    check("cycles_per_long_break", opts.cycles_per_long_break, "number")
    if opts.cycles_per_long_break < 1 then
      error("pomodoro: cycles_per_long_break must be >= 1", 2)
    end
  end
  if opts.daily_goal ~= nil then
    check("daily_goal", opts.daily_goal, "number")
    if opts.daily_goal < 0 then
      error("pomodoro: daily_goal must be >= 0", 2)
    end
  end
  if opts.sound then
    check("sound", opts.sound, "table")
    check("sound.enabled", opts.sound.enabled, "boolean", true)
    if opts.sound.cmd ~= nil then
      local t = type(opts.sound.cmd)
      if t ~= "string" and t ~= "table" then
        error("pomodoro: sound.cmd must be a string or a list of arguments", 2)
      end
    end
  end
  if opts.notify_styles then
    check("notify_styles", opts.notify_styles, "table")
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

--- @param user_opts? pomodoro.Config
function M.merge(user_opts)
  validate(user_opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), user_opts or {})
  return M.options
end

function M.get()
  return M.options
end

return M
