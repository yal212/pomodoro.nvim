local Config = require("pomodoro.config")

local M = {}

local function default_path()
  return vim.fs.joinpath(vim.fn.stdpath("data"), "pomodoro", "stats.json")
end

function M.path()
  local p = Config.get().persistence.path
  if p and #p > 0 then
    return p
  end
  return default_path()
end

local function ensure_dir(path)
  local dir = vim.fs.dirname(path)
  vim.fn.mkdir(dir, "p")
end

local function read_file(path)
  local fd = vim.uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end
  local stat = vim.uv.fs_fstat(fd)
  if not stat then
    vim.uv.fs_close(fd)
    return nil
  end
  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  return data
end

local function write_atomic(path, content)
  ensure_dir(path)
  local tmp = path .. ".tmp"
  local fd = vim.uv.fs_open(tmp, "w", 420)
  if not fd then
    return false, "open " .. tmp .. " failed"
  end
  local ok, err = vim.uv.fs_write(fd, content, 0)
  vim.uv.fs_close(fd)
  if not ok then
    vim.uv.fs_unlink(tmp)
    return false, err
  end
  local renamed, rename_err = vim.uv.fs_rename(tmp, path)
  if not renamed then
    vim.uv.fs_unlink(tmp)
    return false, rename_err
  end
  return true
end

function M.empty_db()
  return { version = 1, days = {} }
end

function M.load()
  if not Config.get().persistence.enabled then
    return M.empty_db()
  end
  local path = M.path()
  local data = read_file(path)
  if not data or #data == 0 then
    return M.empty_db()
  end
  local ok, decoded = pcall(vim.json.decode, data)
  if not ok or type(decoded) ~= "table" then
    local kept = vim.uv.fs_rename(path, path .. ".bak") ~= nil
    vim.notify(
      "pomodoro: stats.json corrupt, starting fresh"
        .. (kept and " (kept at " .. path .. ".bak)" or ""),
      vim.log.levels.WARN,
      { title = "Pomodoro" }
    )
    return M.empty_db()
  end
  if type(decoded.days) ~= "table" then
    decoded.days = {}
  end
  decoded.version = decoded.version or 1
  return decoded
end

function M.save(db)
  if not Config.get().persistence.enabled then
    return true
  end
  local ok, encoded = pcall(vim.json.encode, db)
  if not ok then
    return false, encoded
  end
  return write_atomic(M.path(), encoded)
end

return M
