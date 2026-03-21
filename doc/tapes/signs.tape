# GIF — Heat-gradient signs in sign column and line numbers

Output doc/tapes/output/signs.webp

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
Type "nvim compute.go"
Enter
Sleep 3s
Type ":luafile sign_override.lua"
Enter
Sleep 500ms
Type ":PProfLoad cpu.prof"
Enter
Sleep 2s
Show

# Show heat signs on line numbers (default)
Sleep 1s

# Navigate to the hot matrixMultiply function
Type ":10"
Enter
Sleep 1s

Type "10j"
Sleep 1.5s

# Toggle sign column glyph to show both channels
Type ":lua require('pprof').show_signhl()"
Enter
Sleep 1.5s

# Scroll down to sieve function
Type ":36"
Enter
Sleep 1s

Type "15j"
Sleep 1s

# Toggle full-line background
Type ":lua require('pprof').show_linehl()"
Enter
Sleep 1.5s

# Scroll to sort workload
Type ":52"
Enter
Sleep 1s

Type ":qa!"
Enter
