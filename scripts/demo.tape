# README demo — regenerate with: vhs scripts/demo.tape  (https://github.com/charmbracelet/vhs)
Output assets/demo.gif

Set FontSize 15
Set Width 1000
Set Height 600
Set Padding 10
Set TypingSpeed 55ms
Set Theme "Catppuccin Mocha"

Hide
Type "nvim --clean -u scripts/demo_init.lua"
Enter
Sleep 3s
Show

Sleep 1.5s
Type ":Pomodoro start"
Sleep 500ms
Enter
Sleep 2s

Type ":Pomodoro status"
Sleep 500ms
Enter

# Work block (12s) ends on camera -> short break (6s) -> next work auto-starts.
Sleep 17s

Type ":Pomodoro history 7"
Sleep 500ms
Enter
Sleep 4s
Type "q"
Sleep 2s

Hide
Type ":qa!"
Enter
