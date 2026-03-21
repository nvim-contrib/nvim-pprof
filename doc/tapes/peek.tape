# Screenshot — Peek callers/callees floating window

Output doc/tapes/output/peek.png

Set Shell "zsh"
Set FontSize 18
Set Width 1200
Set Height 700
Set Theme "Catppuccin Mocha"
Set FontFamily "JetBrainsMono Nerd Font"
Set CursorBlink false
Set Padding 20

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

# Navigate to matrixMultiply function
Type ":10"
Enter
Sleep 500ms

# Peek the function under cursor
Type ":PProfPeek matrixMultiply"
Enter
Sleep 1.5s

Screenshot doc/tapes/output/peek.png
