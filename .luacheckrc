-- vim: ft=lua tw=80
std = luajit
cache = true
codes = true

read_globals = {
  "vim",
}

self = false

ignore = {
  "212/_.*", -- Unused argument, for vars with "_" prefix
  "631",     -- Line is too long
}

exclude_files = {
  "tests/.deps/",
}
