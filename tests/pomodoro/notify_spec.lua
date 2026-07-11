---@diagnostic disable: undefined-field
describe("notify", function()
  local Config = require("pomodoro.config")
  local Notify = require("pomodoro.notify")

  local captured, real_notify

  local function editor_floats()
    local wins = {}
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(w).relative == "editor" then
        wins[#wins + 1] = w
      end
    end
    return wins
  end

  before_each(function()
    Config.merge(nil)
    captured = {}
    real_notify = vim.notify
    vim.notify = function(msg, level, opts)
      captured[#captured + 1] = { msg = msg, level = level, opts = opts }
    end
  end)

  after_each(function()
    vim.notify = real_notify
    for _, w in ipairs(editor_floats()) do
      pcall(vim.api.nvim_win_close, w, true)
    end
  end)

  it("sends through vim.notify with the Pomodoro title", function()
    Config.merge({ notify_styles = { "vim_notify" } })
    Notify.send("hi")
    assert.equals(1, #captured)
    assert.equals("hi", captured[1].msg)
    assert.equals(vim.log.levels.INFO, captured[1].level)
    assert.equals("Pomodoro", captured[1].opts.title)
  end)

  it("maps level names, defaulting unknown ones to INFO", function()
    Config.merge({ notify_styles = { "vim_notify" } })
    Notify.send("w", "warn")
    Notify.send("e", "error")
    Notify.send("x", "loud")
    assert.equals(vim.log.levels.WARN, captured[1].level)
    assert.equals(vim.log.levels.ERROR, captured[2].level)
    assert.equals(vim.log.levels.INFO, captured[3].level)
  end)

  it("shows a float containing the message", function()
    Config.merge({ notify_styles = { "float" }, notify = { float_duration_ms = 50 } })
    local before = #editor_floats()
    Notify.send("hello")
    local floats = editor_floats()
    assert.equals(before + 1, #floats)
    local buf = vim.api.nvim_win_get_buf(floats[#floats])
    local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    assert.truthy(line:find("hello", 1, true))
    assert.equals(0, #captured)
  end)

  it("dispatches to every configured style", function()
    Config.merge({ notify_styles = { "vim_notify", "float" } })
    local before = #editor_floats()
    Notify.send("both")
    assert.equals(1, #captured)
    assert.equals(before + 1, #editor_floats())
  end)

  it("does nothing with no styles configured", function()
    Config.merge({ notify_styles = {} })
    local before = #editor_floats()
    Notify.send("silent")
    assert.equals(0, #captured)
    assert.equals(before, #editor_floats())
  end)
end)
