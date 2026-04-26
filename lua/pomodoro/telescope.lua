local M = {}

local function load_telescope()
  local ok, telescope = pcall(require, "telescope")
  if not ok then
    return nil
  end
  return telescope
end

function M.register()
  local telescope = load_telescope()
  if not telescope then
    return false
  end
  telescope.register_extension({
    exports = {
      stats = M.picker,
      pomodoro = M.picker,
    },
  })
  return true
end

function M.picker(opts)
  opts = opts or {}
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local previewers = require("telescope.previewers")
  local Stats = require("pomodoro.stats")

  local rows = Stats.last_n_days(30)
  local entries = {}
  for _, row in ipairs(rows) do
    entries[#entries + 1] = {
      value = row,
      display = string.format(
        "%s  %2d work  %3d min",
        row.date,
        row.data.completed_work,
        row.data.minutes_focused
      ),
      ordinal = row.date,
    }
  end
  -- Reverse so most recent is on top
  local reversed = {}
  for i = #entries, 1, -1 do
    reversed[#reversed + 1] = entries[i]
  end

  pickers
    .new(opts, {
      prompt_title = "Pomodoro stats — last 30 days",
      finder = finders.new_table({
        results = reversed,
        entry_maker = function(e)
          return {
            value = e.value,
            display = e.display,
            ordinal = e.ordinal,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer({
        title = "Day breakdown",
        define_preview = function(self, entry)
          local d = entry.value.data
          local lines = {
            "Date: " .. entry.value.date,
            "",
            string.format("  Completed work blocks : %d", d.completed_work),
            string.format("  Long breaks taken     : %d", d.completed_long_breaks),
            string.format("  Minutes focused       : %d", d.minutes_focused),
          }
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        end,
      }),
    })
    :find()
end

return M
