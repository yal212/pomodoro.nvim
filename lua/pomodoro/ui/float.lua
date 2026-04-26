local M = {}

local function open_centered(lines, opts)
  local height = #lines
  local width = 0
  for _, l in ipairs(lines) do
    if #l > width then
      width = #l
    end
  end
  width = math.max(width, 20)
  width = math.min(width, vim.o.columns - 4)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "pomodoro"

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width + 2,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width - 2) / 2),
    style = "minimal",
    border = opts.border or "rounded",
    focusable = false,
    noautocmd = true,
  })
  vim.wo[win].winhighlight = "Normal:Normal,FloatBorder:FloatBorder"

  return buf, win
end

function M.flash(lines, duration_ms, border)
  local buf, win = open_centered(lines, { border = border })
  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  vim.defer_fn(close, duration_ms)
  return close
end

return M
