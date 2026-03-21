# GIF — Top-N function summary floating window

Output doc/tapes/output/top.webp

Set Shell "zsh"
Set FontSize 18
Set Width 1200
Set Height 700
Set Theme "Catppuccin Mocha"
Set FontFamily "JetBrainsMono Nerd Font"
Set Framerate 15
Set CursorBlink false
Set Padding 20
Set TypingSpeed 75ms

Hide
Type "cd doc/tapes/demo && clear"
Enter
Sleep 500ms
Show

Type "nvim compute.go"
Enter
Sleep 3s

Type ":luafile sign_override.lua"
Enter
Sleep 500ms
Type ":PProfLoad cpu.prof"
Enter
Sleep 2s

Type ":PProfTop"
Enter
Sleep 1.5s

# Sort by cumulative
Type "sc"
Sleep 1.5s

# Sort by flat
Type "sf"
Sleep 1.5s

# Navigate down
Type "3j"
Sleep 500ms

# Jump to source
Type@50ms ""
Sleep 1.5s

Type ":qa!"
Enter
