---@diagnostic disable: undefined-field
describe("commands", function()
  local calls, notes

  before_each(function()
    calls = {}
    notes = {}
    -- commands.lua requires these lazily at dispatch time, so stubbing
    -- package.loaded intercepts every subcommand handler
    package.loaded["pomodoro"] = setmetatable({}, {
      __index = function(_, key)
        return function(arg)
          calls[#calls + 1] = { name = key, arg = arg }
        end
      end,
    })
    package.loaded["pomodoro.notify"] = {
      send = function(msg, level)
        notes[#notes + 1] = { msg = msg, level = level }
      end,
    }
    require("pomodoro.commands").register()
  end)

  after_each(function()
    package.loaded["pomodoro"] = nil
    package.loaded["pomodoro.notify"] = nil
  end)

  it("dispatches subcommands with their arguments", function()
    vim.cmd("Pomodoro start work")
    vim.cmd("Pomodoro history 5")
    assert.same({ name = "start", arg = "work" }, calls[1])
    assert.same({ name = "history", arg = "5" }, calls[2])
  end)

  it("matches subcommands case-insensitively", function()
    vim.cmd("Pomodoro Start")
    vim.cmd("Pomodoro STOP")
    assert.same({ name = "start" }, calls[1])
    assert.same({ name = "stop" }, calls[2])
  end)

  it("shows usage for unknown or missing subcommands without erroring", function()
    vim.cmd("Pomodoro bogus")
    vim.cmd("Pomodoro")
    assert.equals(0, #calls)
    assert.equals(2, #notes)
    for _, note in ipairs(notes) do
      assert.truthy(note.msg:find("Usage: :Pomodoro", 1, true))
      assert.equals("error", note.level)
    end
  end)

  it("completes subcommand names on the first argument", function()
    assert.same(
      { "skip", "start", "stats", "status", "stop" },
      vim.fn.getcompletion("Pomodoro s", "cmdline")
    )
  end)

  it("completes phases after start, even capitalized", function()
    assert.same({ "work", "short", "long" }, vim.fn.getcompletion("Pomodoro start ", "cmdline"))
    assert.same({ "work" }, vim.fn.getcompletion("Pomodoro Start w", "cmdline"))
    assert.same({}, vim.fn.getcompletion("Pomodoro stop ", "cmdline"))
  end)

  it("does not define the old per-action commands", function()
    assert.equals(0, vim.fn.exists(":PomodoroStart"))
    assert.equals(0, vim.fn.exists(":PomodoroStop"))
  end)
end)
