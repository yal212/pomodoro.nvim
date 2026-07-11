# Focus-mode demo — regenerate with: vhs scripts/demo_focus.tape  (https://github.com/charmbracelet/vhs)
# Storyline (~15s): start work -> diagnostics silenced + inactive window dimmed
# -> :Lazy and :Mason blocked -> break starts -> :Lazy runs again.
#
# Timing is load-bearing. demo_focus_init.lua sets work = 9.6s, break = 6s.
# Work starts at ~t=2s, so both blocked commands must land before ~t=11.6s, and
# the recording must end before the break expires at ~t=17.6s (which would pop
# the continue/stop prompt).
Output assets/focus.gif

Set FontSize 15
Set Width 1100
Set Height 640
Set Padding 10
Set TypingSpeed 40ms
Set Theme "Catppuccin Mocha"

# Boot Neovim off-camera with the focus demo init.
Hide
Type "nvim --clean -u scripts/demo_focus_init.lua"
Enter
Sleep 3s
Show

# Beat 1 — the "before": diagnostics visible, both windows equally lit.
Sleep 1.2s

# Beat 2 — start work. On camera the diagnostics vanish and the inactive
# window darkens as focus mode engages.
Type ":Pomodoro start"
Sleep 250ms
Enter
Sleep 1.6s

# Live countdown in the pinned status window.
Type ":Pomodoro status"
Sleep 250ms
Enter
Sleep 1.2s

# Beat 3 — the payoff: reach for the plugin manager mid-work. Blocked.
Type ":Lazy"
Sleep 400ms
Enter
Sleep 2.2s

# Once more, to show it's a list and not a one-off. Also blocked.
Type ":Mason"
Sleep 400ms
Enter
Sleep 1.8s

# Beat 4 — work expires and rolls into the break: diagnostics return, dim lifts.
Sleep 1.2s

# Beat 5 — on the break, the same command is allowed again.
Type ":Lazy"
Sleep 400ms
Enter
Sleep 2.2s

Hide
Type ":qa!"
Enter
