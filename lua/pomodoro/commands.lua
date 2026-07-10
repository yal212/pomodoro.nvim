local M = {}

local function pomodoro()
  return require("pomodoro")
end

-- Subcommand names are matched case-insensitively (:Pomodoro Start == :Pomodoro start).
local subcommands = {
  start = {
    run = function(args)
      pomodoro().start(args[1])
    end,
    complete = { "work", "short", "long" },
  },
  pause = {
    run = function()
      pomodoro().pause()
    end,
  },
  resume = {
    run = function()
      pomodoro().resume()
    end,
  },
  stop = {
    run = function()
      pomodoro().stop()
    end,
  },
  skip = {
    run = function()
      pomodoro().skip()
    end,
  },
  restart = {
    run = function()
      pomodoro().restart()
    end,
  },
  status = {
    run = function()
      pomodoro().status()
    end,
  },
  stats = {
    run = function()
      pomodoro().stats_summary()
    end,
  },
  history = {
    run = function(args)
      pomodoro().history(args[1])
    end,
  },
  reset = {
    run = function()
      vim.ui.select({ "yes", "no" }, { prompt = "Wipe all pomodoro stats?" }, function(choice)
        if choice == "yes" then
          pomodoro().reset_stats()
        end
      end)
    end,
  },
}

local subcommand_names = vim.tbl_keys(subcommands)
table.sort(subcommand_names)

local function usage()
  return "Usage: :Pomodoro {" .. table.concat(subcommand_names, "|") .. "}"
end

local function dispatch(opts)
  -- :Pomodoro is registered from plugin/pomodoro.lua, so it can run before
  -- setup(); initialize with defaults on first use in that case.
  if not pomodoro()._is_setup() then
    pomodoro().setup({})
  end
  local name = (opts.fargs[1] or ""):lower()
  local sub = subcommands[name]
  if not sub then
    require("pomodoro.notify").send(usage(), "error")
    return
  end
  local args = {}
  for i = 2, #opts.fargs do
    args[#args + 1] = opts.fargs[i]
  end
  sub.run(args)
end

local function prefix_filter(candidates, arglead)
  local lead = arglead:lower()
  return vim.tbl_filter(function(c)
    return vim.startswith(c, lead)
  end, candidates)
end

local function complete(arglead, cmdline)
  -- A completed first argument means we're on a subcommand's own arguments.
  local name = cmdline:match("^%s*['<,>%d]*%s*Pomodoro!?%s+(%S+)%s")
  if name then
    local sub = subcommands[name:lower()]
    return sub and sub.complete and prefix_filter(sub.complete, arglead) or {}
  end
  return prefix_filter(subcommand_names, arglead)
end

function M.register()
  vim.api.nvim_create_user_command("Pomodoro", dispatch, {
    nargs = "*",
    complete = complete,
    desc = "Pomodoro timer commands",
  })

  pcall(function()
    require("pomodoro.telescope").register()
  end)
end

return M
