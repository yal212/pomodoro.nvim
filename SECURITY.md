# Security Policy

pomodoro.nvim is a pure-Lua Neovim plugin that runs locally, makes no network
requests, and only writes to its own stats file under Neovim's data directory.
Its attack surface is small, but security reports are still taken seriously.

## Supported versions

Only the latest release receives security fixes.

## Reporting a vulnerability

Please **do not** open a public issue for security problems. Instead:

- Use GitHub's private reporting: **Security → Report a vulnerability** on the
  [repository page](https://github.com/yal212/pomodoro.nvim/security), or
- Email <yal212yal@gmail.com>

You can expect an initial response within a week. Please include reproduction
steps and the plugin/Neovim versions affected.
