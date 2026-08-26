# CLAUDE.md

Project instructions for Claude Code working in this repository.

## Attribution

Do not append Claude Code attribution to commit messages or pull request bodies. Specifically,
never add:

- a "Generated with Claude Code" footer
- a `Claude-Session:` trailer, or a bare session link to `claude.ai`
- a `Co-Authored-By: Claude ...` trailer

Commits and PR descriptions should read as the maintainer's own work.

## Workflow

- `main` never takes direct pushes — branch, open a PR, and merge it there.
- Before pushing: `stylua --check lua/ tests/ plugin/`, `luacheck lua/ plugin/`, and the plenary
  spec suite must all be clean.
