---@diagnostic disable: undefined-field
describe("focus", function()
  local Focus, Config

  before_each(function()
    package.loaded["pomodoro.config"] = nil
    package.loaded["pomodoro.focus"] = nil
    Config = require("pomodoro.config")
    Focus = require("pomodoro.focus")
  end)

  it("blocks exact command name match", function()
    Config.merge({ focus = { enabled = true, blocked_commands = { "Lazy", "Mason" } } })
    local blocked, name = Focus._check_command("Lazy")
    assert.is_true(blocked)
    assert.equals("Lazy", name)
  end)

  it("is case-insensitive", function()
    Config.merge({ focus = { enabled = true, blocked_commands = { "lazy" } } })
    local blocked = Focus._check_command("LAZY sync")
    assert.is_true(blocked)
  end)

  it("does not block unrelated commands", function()
    Config.merge({ focus = { enabled = true, blocked_commands = { "Lazy" } } })
    local blocked = Focus._check_command("write")
    assert.is_false(blocked)
  end)

  it("treats empty list as no blocks", function()
    Config.merge({ focus = { enabled = true, blocked_commands = {} } })
    local blocked = Focus._check_command("Lazy")
    assert.is_false(blocked)
  end)

  describe("dim_inactive", function()
    local function dimmed(win)
      return vim.wo[win].winhighlight:find("NormalNC:PomodoroDimNC", 1, true) ~= nil
    end

    before_each(function()
      Config.merge({ focus = { enabled = true, dim_inactive = true } })
      Focus.setup()
    end)

    after_each(function()
      Focus.on_work_end()
      vim.cmd("only")
      vim.wo.winhighlight = ""
    end)

    it("dims all normal windows on work start", function()
      vim.cmd("split")
      Focus.on_work_start()
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        assert.is_true(dimmed(w))
      end
    end)

    it("dims windows opened mid-phase and undims them on work end", function()
      Focus.on_work_start()
      vim.cmd("split")
      local w = vim.api.nvim_get_current_win()
      assert.is_true(dimmed(w))
      -- the split inherited the dimmed winhighlight; make sure the saved
      -- restore value doesn't keep it dimmed forever
      Focus.on_work_end()
      assert.is_false(dimmed(w))
    end)

    it("restores previous winhighlight on work end", function()
      vim.wo.winhighlight = "Normal:Comment"
      Focus.on_work_start()
      Focus.on_work_end()
      assert.equals("Normal:Comment", vim.wo.winhighlight)
    end)

    it("leaves floating windows untouched", function()
      local buf = vim.api.nvim_create_buf(false, true)
      local float = vim.api.nvim_open_win(buf, false, {
        relative = "editor",
        row = 0,
        col = 0,
        width = 10,
        height = 2,
      })
      Focus.on_work_start()
      assert.is_false(dimmed(float))
      vim.api.nvim_win_close(float, true)
    end)

    it("does not dim when dim_inactive is off", function()
      Config.merge({ focus = { enabled = true, dim_inactive = false } })
      Focus.on_work_start()
      assert.is_false(dimmed(vim.api.nvim_get_current_win()))
    end)
  end)

  -- CmdlineLeave only sees what the user types at ':'. Mappings built with
  -- <cmd>…<cr> never open a cmdline, which is how most configs reach a plugin.
  describe("blocking commands that bypass the cmdline", function()
    local NAME = "PomodoroSpecCmd"
    local ran

    local function define(opts)
      ran = 0
      vim.api.nvim_create_user_command(NAME, function()
        ran = ran + 1
      end, opts or {})
    end

    local function command_def(name)
      return vim.api.nvim_get_commands({ builtin = false })[name]
    end

    after_each(function()
      Focus.on_work_end()
      pcall(vim.api.nvim_del_user_command, NAME)
      pcall(vim.keymap.del, "n", "g<F5>")
    end)

    it("refuses a command invoked through a <cmd> mapping during work", function()
      define()
      Config.merge({ focus = { enabled = true, blocked_commands = { NAME } } })
      Focus.on_work_start()
      vim.keymap.set("n", "g<F5>", "<cmd>" .. NAME .. "<cr>")
      vim.api.nvim_feedkeys("g<F5>", "x", false)
      assert.equals(0, ran)
      assert.same({ NAME }, Focus._shimmed_commands())
    end)

    it("hands the command back when the work block ends", function()
      define()
      Config.merge({ focus = { enabled = true, blocked_commands = { NAME } } })
      Focus.on_work_start()
      Focus.on_work_end()
      assert.same({}, Focus._shimmed_commands())
      vim.cmd(NAME)
      assert.equals(1, ran)
    end)

    it("restores the command's original attributes", function()
      define({ nargs = "*", bang = true, range = true, desc = "the real thing" })
      local before = command_def(NAME)
      Config.merge({ focus = { enabled = true, blocked_commands = { NAME } } })
      Focus.on_work_start()
      Focus.on_work_end()
      local after = command_def(NAME)
      for _, field in ipairs({ "nargs", "bang", "range", "definition" }) do
        assert.equals(before[field], after[field])
      end
    end)

    it("leaves a name alone when no such command exists", function()
      Config.merge({ focus = { enabled = true, blocked_commands = { "PomodoroNoSuchCmd" } } })
      Focus.on_work_start()
      assert.same({}, Focus._shimmed_commands())
      assert.is_nil(command_def("PomodoroNoSuchCmd"))
    end)

    it("does not touch commands while focus mode is off", function()
      define()
      Config.merge({ focus = { enabled = false, blocked_commands = { NAME } } })
      Focus.on_work_start()
      vim.cmd(NAME)
      assert.equals(1, ran)
    end)
  end)
end)
