# nvim-pprof

> Go pprof profiler integration for Neovim

![test](https://github.com/nvim-contrib/nvim-pprof/actions/workflows/test.yml/badge.svg)
![license](https://img.shields.io/github/license/nvim-contrib/nvim-pprof)

## Features

- Load and parse Go pprof profiles (CPU, memory, allocations)
- Heat-gradient signs in the sign column and line numbers showing hot/cold lines
- Inline virtual text hints showing flat/cum values per line
- Floating top-N function summary window with sort-by-flat/cum
- Peek window showing callers/callees for any function
- Location list populated with all profiled hotspot lines
- File watcher for auto-reload when profiles change on disk
- LSP code actions for peek (integrates with `vim.lsp.buf.code_action()`)

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

The `setup` function accepts an optional table to override any defaults:

```lua
require("pprof").setup({
  -- Path to the Go binary used to invoke `go tool pprof`
  pprof_bin = "go",
  -- Sign column display options
  signs = {
    -- Number of heat gradient levels (1-5)
    heat_levels = 5,
    -- Sign priority
    priority = 10,
    -- Highlight the sign column
    signhl = false,
    -- Highlight line numbers with heat gradient
    numhl = true,
    -- Highlight entire lines with heat gradient
    linehl = false,
  },
  -- Inline virtual text hints
  hints = {
    -- Enable hints on profile load
    enabled = false,
    -- Format string for hint text ({flat} and {cum} are replaced)
    format = "{flat} flat | {cum} cum",
  },
  -- Top-N function summary window
  top = {
    -- Default number of functions to show
    default_count = 20,
  },
  -- File watcher for auto-reload
  watch = {
    -- Enable file watching on profile load
    enabled = false,
    -- Debounce interval in milliseconds
    debounce_ms = 500,
  },
  -- Callback invoked after a profile is loaded
  on_load = nil,
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

### LSP code actions

nvim-pprof registers a virtual LSP client. When the cursor is on a function
name or call in a Go file, `vim.lsp.buf.code_action()` includes a
**pprof: Peek funcName** action that opens the peek window for that function.

## Contributing

Contributions are welcome! Please open an issue or pull request on
[GitHub](https://github.com/nvim-contrib/nvim-pprof).

## License

[MIT](LICENSE)
