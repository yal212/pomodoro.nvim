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
end)
