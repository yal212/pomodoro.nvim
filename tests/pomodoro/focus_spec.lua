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

    it("dims windows opened mid-phase", function()
      Focus.on_work_start()
      vim.cmd("split")
      assert.is_true(dimmed(vim.api.nvim_get_current_win()))
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
end)
