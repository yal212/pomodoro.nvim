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
        vim.notify(
          string.format("pomodoro focus: %q blocked during work", name),
          vim.log.levels.WARN,
          { title = "Pomodoro" }
        )
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
  if opts.focus.dim_inactive then
    require("pomodoro.ui.highlights").ensure_highlights()
    dimming = true
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      dim_win(w)
    end
  end
end

function M.on_work_end()
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

return M
