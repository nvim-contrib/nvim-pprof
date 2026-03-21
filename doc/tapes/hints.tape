# GIF — Inline virtual text hints with flat/cum values

Output doc/tapes/output/hints.webp

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

# Show inline hints
Type ":PProfHints show"
Enter
Sleep 1.5s

# Navigate to hot function
Type ":10"
Enter
Sleep 1s

Type "10j"
Sleep 1.5s

# Scroll to sieve
Type ":36"
Enter
Sleep 1s

Type "15j"
Sleep 1.5s

Type ":qa!"
Enter
