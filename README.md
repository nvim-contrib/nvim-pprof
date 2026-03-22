# nvim-pprof

> Go pprof profiler integration for Neovim

[![test](https://github.com/nvim-contrib/nvim-pprof/actions/workflows/test.yml/badge.svg)](https://github.com/nvim-contrib/nvim-pprof/actions/workflows/test.yml)
[![Release](https://img.shields.io/github/v/release/nvim-contrib/nvim-pprof?include_prereleases)](https://github.com/nvim-contrib/nvim-pprof/releases)
[![License](https://img.shields.io/github/license/nvim-contrib/nvim-pprof)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.11%2B-blueviolet?logo=neovim&logoColor=white)](https://neovim.io)

## Features

- Load and parse Go pprof profiles (CPU, memory, allocations)
- Heat-gradient signs in the sign column and line numbers showing hot/cold lines
- Inline virtual text hints showing flat/cum values per line
- Floating top-N function summary window with sort-by-flat/cum
- Peek window showing callers/callees for any function
- Location list populated with all profiled hotspot lines
- File watcher for auto-reload when profiles change on disk

![signs](doc/tapes/output/signs.webp)

## Requirements

- Neovim >= 0.11
- Go toolchain (`go tool pprof`)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "nvim-contrib/nvim-pprof",
  opts = {},
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use({
  "nvim-contrib/nvim-pprof",
  config = function()
    require("pprof").setup()
  end,
})
```

## Generating profile files

Generate a CPU profile by running your Go tests or application with profiling enabled:

```sh
# CPU profile from tests
go test -cpuprofile cpu.prof -bench .

# Memory profile from tests
go test -memprofile mem.prof -bench .

# CPU profile from a running application
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30
```

The resulting `.prof` files can be loaded directly by nvim-pprof.

## Configuration

```lua
require("pprof").setup({
  -- path to the Go binary used to invoke `go tool pprof`
  pprof_bin = "go",

  -- register :PProf* commands (default: true)
  commands = true,

  auto_reload = {
    enabled    = false, -- auto-reload profile when .prof file changes on disk
    timeout_ms = 500,   -- debounce delay before reloading
  },

  -- called after a profile is loaded
  on_load = nil,

  signs = {
    cold        = { hl = "PprofHeatCold", text = "▎" }, -- coldest lines
    warm        = { hl = "PprofHeatWarm", text = "▎" }, -- mid-range lines
    hot         = { hl = "PprofHeatHot",  text = "▎" }, -- hottest lines
    group       = "pprof",  -- sign group name (:h sign-group)
    signhl      = false,    -- show glyph in sign column (toggleable at runtime)
    numhl       = true,     -- color the line number (toggleable at runtime)
    linehl      = false,    -- color the entire line background (toggleable at runtime)
    heat_levels = 5,        -- number of gradient steps between cold and hot
  },

  -- heat gradient anchor colors (cold → warm → hot)
  highlights = {
    cold = { fg = "#3b82f6", bg = "#1e3a5f" },
    warm = { fg = "#f59e0b", bg = "#7a4f05" },
    hot  = { fg = "#ef4444", bg = "#7f1d1d" },
  },

  -- inline virtual text showing flat/cum values per line
  line_hints = {
    enabled   = false,                     -- show hints automatically after load
    format    = "{flat} flat | {cum} cum", -- {flat} and {cum} are substituted
    position  = "eol",                     -- "eol" | "right_align" | "inline"
    highlight = { link = "Comment" },
  },

  -- top-N function summary floating window
  top = {
    default_count = 20,
    border        = "rounded",
    width         = 0.70,  -- fraction of editor columns
    height        = 0.50,  -- fraction of editor lines
    min_flat_pct  = 5.0,   -- threshold: flat% >= this gets `fail` colour; 0 disables
    window        = {},    -- extra options passed to nvim_open_win
    highlights = {
      header        = { link = "Title" },
      column_header = { link = "Comment" },
      border        = { link = "FloatBorder" },
      normal        = { link = "NormalFloat" },
      cursor_line   = { link = "CursorLine" },
      pass          = { link = "Comment" },       -- flat% below threshold
      fail          = { link = "DiagnosticWarn" }, -- flat% at or above threshold
    },
  },

  -- callers/callees peek floating window
  peek = {
    border  = "rounded",
    width   = 0,  -- 0 = auto-size to content; fraction > 0 = fixed ratio
    height  = 0,
    window  = {},
    highlights = {
      header      = { link = "Title" },
      border      = { link = "FloatBorder" },
      normal      = { link = "NormalFloat" },
      cursor_line = { link = "CursorLine" },
    },
  },
})
```

## Usage

### Commands

| Command                | Description                                                                                          |
| ---------------------- | ---------------------------------------------------------------------------------------------------- |
| `:PProfLoad[!] [file]` | Load a `.prof` file. No argument auto-finds in cwd. `!` shows a picker when multiple files are found |
| `:PProfSigns [action]` | Show/hide/toggle heat signs. Default: toggle                                                         |
| `:PProfHints [action]` | Show/hide/toggle inline hints. Default: toggle                                                       |
| `:PProfTop [count]`    | Show top-N functions in a floating window                                                            |
| `:PProfPeek [func]`    | Show callers/callees. No argument uses treesitter to detect the function at cursor                   |
| `:PProfQuickfix`       | Populate quickfix list with one entry per profiled file                                               |
| `:PProfLoclist`        | Populate location list with hotspot lines                                                            |
| `:PProfClear`          | Clear all profile data, signs, hints, and floats                                                     |

![hints](doc/tapes/output/hints.webp)

### Lua API

```lua
local pprof = require("pprof")

-- load
pprof.load()                          -- auto-find .prof in cwd
pprof.load("path/to/cpu.prof")        -- load from explicit path
pprof.load(nil, true)                 -- force picker

-- signs (all channels)
pprof.show_signs()
pprof.hide_signs()
pprof.toggle_signs()

-- sign column glyph / line number / full-line background (runtime toggles)
pprof.show_signhl()   pprof.hide_signhl()   pprof.toggle_signhl()
pprof.show_numhl()    pprof.hide_numhl()    pprof.toggle_numhl()
pprof.show_linehl()   pprof.hide_linehl()   pprof.toggle_linehl()

-- inline hints
pprof.show_hints()
pprof.hide_hints()
pprof.toggle_hints()

-- floating windows
pprof.top(count)
pprof.peek(func_name)

-- quickfix / loclist navigation
pprof.quickfix()
pprof.loclist()

-- jump to next/previous hotspot sign
pprof.jump_next()
pprof.jump_prev()

-- clear
pprof.clear()
```

### Top window keys

| Key         | Action         |
| ----------- | -------------- |
| `sf`        | Sort by flat   |
| `sc`        | Sort by cum    |
| `Enter`     | Jump to source |
| `q` / `Esc` | Close          |

![top](doc/tapes/output/top.webp)

### Quickfix / loclist workflow

```
:PProfQuickfix   → quickfix list of profiled files, hottest first
:PProfLoclist    → location list of hotspot lines in current file
```

Navigate the quickfix list with `:cnext` / `:cprev` (or `]q` / `[q` with a mapping).
Navigate the location list with `:lnext` / `:lprev`.

### Peek keybinding

`:PProfPeek` detects the function name under the cursor via treesitter, so
you can map it directly:

```lua
vim.keymap.set("n", "<leader>pp", "<cmd>PProfPeek<CR>",
  { desc = "pprof: peek callers/callees" })
```

![peek](doc/tapes/output/peek.png)

## Contributing

Contributions are welcome! Please open an issue or pull request on
[GitHub](https://github.com/nvim-contrib/nvim-pprof).

## License

[MIT](LICENSE)
