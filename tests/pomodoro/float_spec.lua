---@diagnostic disable: undefined-field
describe("ui.float", function()
  local Float = require("pomodoro.ui.float")

  it("sizes panels by display width, not bytes", function()
    -- 30 cells of a 3-byte-per-cell char; byte length would be 90
    local bar = string.rep("█", 30)
    local buf, win = Float.open_panel({ bar })
    assert.truthy(win)
    assert.equals(32, vim.api.nvim_win_get_width(win)) -- content + 2 padding
    vim.api.nvim_win_close(win, true)
    assert.truthy(buf)
  end)

  it("clamps a panel taller than the screen instead of drifting off it", function()
    local saved_lines = vim.o.lines
    vim.o.lines = 24
    local lines = {}
    for i = 1, 60 do
      lines[i] = "row " .. i
    end
    local buf, win = Float.open_panel(lines)
    assert.truthy(win)
    local cfg = vim.api.nvim_win_get_config(win)
    assert.is_true(cfg.row >= 0)
    assert.is_true(cfg.height <= vim.o.lines - 4)
    -- every line is still in the buffer; the panel scrolls rather than truncates
    assert.equals(60, vim.api.nvim_buf_line_count(buf))
    vim.api.nvim_win_close(win, true)
    vim.o.lines = saved_lines
  end)
end)

describe("ui.status", function()
  local Status = require("pomodoro.ui.status")

  after_each(function()
    Status.close()
  end)

  it("follows the editor edge on VimResized", function()
    Status.open()
    assert.is_true(Status.is_open())
    local offset = require("pomodoro.config").get().status_window.col_offset
    vim.o.columns = 200
    vim.api.nvim_exec_autocmds("VimResized", {})
    local wins = vim.api.nvim_list_wins()
    local found
    for _, w in ipairs(wins) do
      local cfg = vim.api.nvim_win_get_config(w)
      if cfg.relative == "editor" then
        found = cfg
      end
    end
    assert.truthy(found)
    assert.equals(vim.o.columns - offset, found.col)
  end)
end)
