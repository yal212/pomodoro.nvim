local M = {}

local function open_centered(lines, opts)
  local height = #lines
  local width = 0
  for _, l in ipairs(lines) do
    -- display cells, not bytes: history bars are multibyte
    local w = vim.api.nvim_strwidth(l)
    if w > width then
      width = w
    end
  end
  width = math.max(width, 20)
  width = math.min(width, vim.o.columns - 4)

  local ok_buf, buf = pcall(vim.api.nvim_create_buf, false, true)
  if not ok_buf or not buf then
    return nil, nil
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "pomodoro"

  local ok_win, win = pcall(vim.api.nvim_open_win, buf, opts.enter or false, {
    relative = "editor",
    width = width + 2,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width - 2) / 2),
    style = "minimal",
    border = opts.border or "rounded",
    focusable = opts.focusable or false,
    noautocmd = true,
  })
  if not ok_win or not win then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return nil, nil
  end
  vim.wo[win].winhighlight = "Normal:Normal,FloatBorder:FloatBorder"

  return buf, win
end

function M.flash(lines, duration_ms, border)
  local buf, win = open_centered(lines, { border = border })
  if not buf or not win then
    return function() end
  end
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

--- Focusable centered float that stays open until dismissed with q/<Esc>.
function M.open_panel(lines, opts)
  opts = opts or {}
  local buf, win = open_centered(lines, {
    border = opts.border or "rounded",
    focusable = true,
    enter = true,
  })
  if not buf or not win then
    return nil, nil
  end
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, silent = true })
  end
  return buf, win
end

return M
