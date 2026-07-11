---@diagnostic disable: undefined-field
describe("keymaps", function()
  local plugs = {
    ["<Plug>(PomodoroStart)"] = "start",
    ["<Plug>(PomodoroPause)"] = "pause",
    ["<Plug>(PomodoroResume)"] = "resume",
    ["<Plug>(PomodoroStop)"] = "stop",
    ["<Plug>(PomodoroSkip)"] = "skip",
    ["<Plug>(PomodoroRestart)"] = "restart",
    ["<Plug>(PomodoroStatus)"] = "status",
    ["<Plug>(PomodoroStats)"] = "stats",
    ["<Plug>(PomodoroHistory)"] = "history",
  }

  before_each(function()
    vim.g.loaded_pomodoro = nil
    vim.cmd("runtime plugin/pomodoro.lua")
  end)

  it("defines all <Plug> mappings without setup()", function()
    for plug, sub in pairs(plugs) do
      local rhs = vim.fn.maparg(plug, "n")
      assert.is_true(rhs ~= "", plug .. " is not mapped")
      assert.truthy(rhs:find("Pomodoro " .. sub, 1, true), plug .. " rhs: " .. rhs)
    end
  end)

  it("routes through :Pomodoro dispatch", function()
    local calls = {}
    package.loaded["pomodoro"] = setmetatable({
      _is_setup = function()
        return true
      end,
    }, {
      __index = function(_, key)
        return function(arg)
          calls[#calls + 1] = { name = key, arg = arg }
        end
      end,
    })
    vim.keymap.set("n", "gT", "<Plug>(PomodoroStart)")
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("gT", true, false, true), "x", false)
    vim.keymap.del("n", "gT")
    package.loaded["pomodoro"] = nil
    assert.same({ { name = "start" } }, calls)
  end)
end)
