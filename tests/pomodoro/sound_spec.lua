---@diagnostic disable: undefined-field
describe("sound", function()
  local Sound

  local function reload(cfg)
    package.loaded["pomodoro.config"] = nil
    package.loaded["pomodoro.sound"] = nil
    require("pomodoro.config").merge(cfg)
    Sound = require("pomodoro.sound")
  end

  it("wraps a string cmd in sh -c", function()
    reload({ sound = { enabled = true, cmd = "paplay /tmp/ding.wav" } })
    assert.same({ "sh", "-c", "paplay /tmp/ding.wav" }, Sound._resolve_cmd())
  end)

  it("uses an argv table as-is", function()
    reload({ sound = { enabled = true, cmd = { "afplay", "ding.aiff" } } })
    assert.same({ "afplay", "ding.aiff" }, Sound._resolve_cmd())
  end)

  it("falls back to the platform default", function()
    reload({ sound = { enabled = true } })
    local cmd = Sound._resolve_cmd()
    if vim.uv.os_uname().sysname == "Darwin" then
      assert.equals("afplay", cmd[1])
    else
      assert.is_nil(cmd)
    end
  end)

  it("rejects invalid sound config", function()
    assert.has_error(function()
      require("pomodoro.config").merge({ sound = { enabled = "yes" } })
    end)
    assert.has_error(function()
      require("pomodoro.config").merge({ sound = { cmd = 5 } })
    end)
  end)
end)
