local Config = require("pomodoro.config")
local State = require("pomodoro.state")

local M = {}

local augroup
local saved_diagnostic_config
local dimmed_wins = {} -- win id -> saved winhighlight string
local dimming = false

local DIM_ENTRY = "NormalNC:PomodoroDimNC"

-- Split windows inherit their parent's winhighlight, so a window created
-- mid-phase may already carry the dim entry; strip it before saving or the
-- "restore" value would keep the window dimmed forever.
local function strip_dim(wh)
  local parts = {}
  for part in wh:gmatch("[^,]+") do
    if part ~= DIM_ENTRY then
      parts[#parts + 1] = part
    end
  end
  return table.concat(parts, ",")
end

-- NormalNC only applies to unfocused windows, so dimming every normal window
-- makes the effect follow the cursor without per-focus bookkeeping.
local function dim_win(w)
  if dimmed_wins[w] ~= nil then
    return
  end
  if vim.api.nvim_win_get_config(w).relative ~= "" then
    return
  end
  local saved = strip_dim(vim.wo[w].winhighlight)
  dimmed_wins[w] = saved
  vim.wo[w].winhighlight = saved ~= "" and (saved .. "," .. DIM_ENTRY) or DIM_ENTRY
end

local function notify_blocked(name)
  vim.notify(
    string.format("pomodoro focus: %q blocked during work", name),
    vim.log.levels.WARN,
    { title = "Pomodoro" }
  )
end

local function blocked_set()
  local set = {}
  for _, name in ipairs(Config.get().focus.blocked_commands or {}) do
    set[name:lower()] = true
  end
  return set
end

local function check_command(cmdline)
  if not cmdline or cmdline == "" then
    return false, nil
  end
  local first = cmdline:match("^%s*(%S+)")
  if not first then
    return false, nil
  end
  if first:sub(1, 1) == ":" then
    first = first:sub(2)
  end
  local set = blocked_set()
  if set[first:lower()] or set[cmdline:lower()] then
    return true, first
  end
  return false, nil
end

-- CmdlineLeave only sees commands the user actually types at the ':' prompt.
-- Most configs reach a plugin through a mapping instead (`<cmd>Lazy<cr>`),
-- which never opens a cmdline, so blocking has to happen at the command level
-- too: swap each blocked user command for a stub while work is running and put
-- the original back when the block ends.
local shimmed = {}

local PROBE_NAME = "PomodoroFocusRestoreProbe"

-- nvim_get_commands reports counts as strings ("0", "1", "5"), but
-- nvim_create_user_command only accepts those as numbers.
local function as_number(v)
  return tonumber(v) or v
end

-- nvim_get_commands describes a command with fields that are not the ones
-- nvim_create_user_command takes; translate one into the other.
local function restore_opts(def)
  local opts = { force = true }
  if def.nargs then
    opts.nargs = as_number(def.nargs)
  end
  -- A -count command reports both `count` and `range`, but create rejects the
  -- pair; `count` is the one that carries the meaning.
  if def.count then
    opts.count = as_number(def.count)
  elseif def.range then
    opts.range = def.range == "." and true or as_number(def.range)
  end
  if def.addr then
    opts.addr = def.addr
  end
  if def.complete then
    opts.complete = def.complete_arg and (def.complete .. "," .. def.complete_arg) or def.complete
  end
  opts.bang = def.bang or nil
  opts.bar = def.bar or nil
  opts.register = def.register or nil
  opts.keepscript = def.keepscript or nil
  -- For a Lua command `definition` holds its desc; "Lua function" is the
  -- placeholder reported when it has none.
  if type(def.callback) == "function" and def.definition and def.definition ~= "Lua function" then
    opts.desc = def.definition
  end
  return opts
end

local function replacement(def)
  if type(def.callback) == "function" then
    return def.callback
  end
  -- A Lua command whose callback this Neovim does not report cannot be
  -- recreated from `definition` alone.
  if
    type(def.definition) == "string"
    and def.definition ~= ""
    and def.definition ~= "Lua function"
  then
    return def.definition
  end
  return nil
end

-- Taking a command away is only safe if we can prove we are able to put it
-- back, so rehearse the restore under a scratch name first.
local function can_restore(def)
  local repl = replacement(def)
  if not repl then
    return false
  end
  local ok = pcall(vim.api.nvim_create_user_command, PROBE_NAME, repl, restore_opts(def))
  pcall(vim.api.nvim_del_user_command, PROBE_NAME)
  return ok
end

local function block_commands()
  local names = Config.get().focus.blocked_commands or {}
  if #names == 0 then
    return
  end
  local defs = vim.api.nvim_get_commands({ builtin = false })
  for _, name in ipairs(names) do
    local def = defs[name]
    -- Commands that do not exist are left alone: creating one would leave
    -- nothing behind on restore. Builtin Ex commands and unrestorable ones
    -- stay covered by the cmdline hook.
    if def and not shimmed[name] and can_restore(def) then
      shimmed[name] = def
      vim.api.nvim_create_user_command(name, function()
        notify_blocked(name)
      end, {
        nargs = "*",
        bang = true,
        bar = true,
        range = true,
        force = true,
        desc = "blocked by pomodoro focus mode",
      })
    end
  end
end

local function unblock_commands()
  for name, def in pairs(shimmed) do
    -- Restore from what we saved, never from current config: a config change
    -- mid-block must not strand a stub.
    pcall(vim.api.nvim_create_user_command, name, replacement(def), restore_opts(def))
  end
  shimmed = {}
end

function M.setup()
  if augroup then
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
  end
  augroup = vim.api.nvim_create_augroup("PomodoroFocus", { clear = true })

  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = augroup,
    pattern = ":",
    callback = function()
      if not Config.get().focus.enabled then
        return
      end
      if State.current.phase ~= State.PHASE.WORK then
        return
      end
      local cmd = vim.fn.getcmdline()
      local blocked, name = check_command(cmd)
      if blocked then
        notify_blocked(name)
        vim.fn.setcmdline("")
      end
    end,
  })

  -- WinNew runs in the context of the new window
  vim.api.nvim_create_autocmd("WinNew", {
    group = augroup,
    callback = function()
      if dimming then
        dim_win(vim.api.nvim_get_current_win())
      end
    end,
  })
end

function M.on_work_start()
  local opts = Config.get()
  if not opts.focus.enabled then
    return
  end
  if opts.focus.silent_diagnostics then
    saved_diagnostic_config = vim.diagnostic.config()
    vim.diagnostic.config({
      virtual_text = false,
      signs = saved_diagnostic_config and saved_diagnostic_config.signs,
    })
  end
  block_commands()
  if opts.focus.dim_inactive then
    require("pomodoro.ui.highlights").ensure_highlights()
    dimming = true
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      dim_win(w)
    end
  end
end

function M.on_work_end()
  unblock_commands()
  if saved_diagnostic_config then
    vim.diagnostic.config(saved_diagnostic_config)
    saved_diagnostic_config = nil
  end
  for w, saved in pairs(dimmed_wins) do
    if vim.api.nvim_win_is_valid(w) then
      vim.wo[w].winhighlight = saved
    end
  end
  dimmed_wins = {}
  dimming = false
end

M._check_command = check_command

--- @return string[] user commands currently replaced by the blocking stub
function M._shimmed_commands()
  return vim.tbl_keys(shimmed)
end

return M
