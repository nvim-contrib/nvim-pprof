# nvim-pprof Demo Project

This directory contains a complete demo project for [nvim-pprof](https://github.com/nvim-contrib/nvim-pprof), a Neovim plugin that visualizes Go pprof profiling data inline in your editor. The demo includes CPU and memory workloads that generate realistic profiling data with clear hotspots.

## Prerequisites

- **Go 1.22 or later** — Required to build and run the demo workload
- **Neovim** — Latest version with nvim-pprof plugin installed and configured
- **pprof viewer** — Recommended for comparing profiles (`go tool pprof`)

### Setting Up nvim-pprof

Add nvim-pprof to your Neovim plugin manager and call `setup()`. Examples:

**Using `lazy.nvim`:**
```lua
{
  "nvim-contrib/nvim-pprof",
  config = function()
    require("pprof").setup()
  end,
}
```

**Using `packer.nvim`:**
```lua
use {
  "nvim-contrib/nvim-pprof",
  config = function()
    require("pprof").setup()
  end,
}
```

**Manual setup (in your init.lua):**
```lua
require("pprof").setup()
```

## Quick Start

### 1. Install and Configure nvim-pprof

Ensure nvim-pprof is installed in your Neovim config with `setup()` called (see **Setting Up nvim-pprof** above).

Verify the plugin is loaded by checking that `:PProfLoad` is available:
```vim
:help PProfLoad
```

### 2. Generate Profiles

Generate CPU and memory profiles by running:

```bash
cd demo
make profile
```

This command will:
- Build a binary from the Go workloads
- Run CPU and memory profiling (~20–30 seconds)
- Generate `cpu.prof` and `mem.prof` files in the current directory
- Clean up the binary (only `.prof` files remain)

You'll see console output like:
```
Starting CPU profiling workload...
CPU profiling complete
Starting memory profiling workload...
Memory profiling complete
Profiles written: cpu.prof, mem.prof
```

### 3. Explore Profiles in Neovim

Open Neovim in the demo directory:

```bash
nvim
```

Load the default profile (CPU):

```vim
:PProfLoad
```

If both `cpu.prof` and `mem.prof` are present, a picker will appear. Select one to visualize it.

### 4. View Profile Data

Once loaded, you'll see:
- **Heat gradient signs** in the sign column (from cold/dark to hot/bright)
- **Virtual-text hints** at the end of lines showing sample counts
- **Cursor navigation** to jump between hot functions

## Command Reference

### Navigation & Viewing

| Command | Description |
|---------|-------------|
| `:PProfTop [N]` | Floating window showing the N hottest functions (default: 10) |
| `:PProfPeek` | Floating window showing callers and callees of the function at cursor |
| `:PProfLoclist` | Populate location list with all sampled functions in current profile |
| `:PProfNext` | Jump to next hottest location in current buffer |
| `:PProfPrev` | Jump to previous hottest location in current buffer |

### Display Control

| Command | Description |
|---------|-------------|
| `:PProfSigns [on\|off]` | Toggle heat gradient signs in sign column (only on lines with samples) |
| `:PProfHints [on\|off]` | Toggle virtual-text hints at end of lines (only on lines with samples) |
| `:PProfLoad [file]` | Load a `.prof` file (auto-discovers if in current dir) |
| `:PProfClear` | Clear all profile data and remove signs/hints |

**Note on hints:** Virtual-text hints (flat and cum values) only appear on lines that have profiling samples. Lines with `. | .` (no samples) won't show hints.

## Switching Between Profiles

To switch from CPU profiling to memory profiling:

1. Clear the current profile:
   ```vim
   :PProfClear
   ```

2. Load the memory profile:
   ```vim
   :PProfLoad mem.prof
   ```

3. Navigate to `allocate.go` to see memory hotspots

## Understanding the Demo Workloads

### CPU Profiling (`compute.go`)

The CPU workload focuses on computation-heavy operations:

- **`matrixMultiply()`** — Matrix multiplication with i-k-j loop; inner accumulation is the hottest line
- **`sieveOfEratosthenes()`** — Prime sieve with hot inner marking loop
- **`fibonacciIterative()`** — Fibonacci with a single hot accumulation line
- **`trigWorkload()`** — Three transcendental calls (`sin`, `cos`, `tan`) on separate lines for graduated heat visualization
- **`sortWorkload()`** — Data sorting with tight refill loop
- **`newMatrix()`** — Matrix initialization with `sin` values

### Memory Profiling (`allocate.go`)

The memory workload focuses on direct memory allocations (tracked by Go's heap profiler):

- **Slice allocations** — `make([]byte, size)` with large byte slices (hottest line)
- **Map allocations** — Map key insertion with `make([]byte)` allocations
- **Append operations** — Dynamic slice growth with `append()` calls
- **Large allocations** — Direct `make([]byte, 1024)` calls in tight loops
- **String conversions** — `string([]byte)` allocations from byte slices

Each allocation pattern appears on a distinct source line, creating a heat gradient across different allocation patterns.

## Troubleshooting

### "E492: Not an editor command: PProfLoad"

**Cause**: nvim-pprof is not installed or `setup()` was not called in your Neovim config.

**Solution**:
1. Ensure nvim-pprof is installed via your plugin manager
2. Add the setup call to your Neovim config (see **Setting Up nvim-pprof** above)
3. Reload your Neovim config or restart Neovim
4. Verify with `:PProfLoad` — it should show an error about `.prof` files, not an unknown command

### "Cannot open file: /path/to/cpu.prof"

**Cause**: Absolute paths in the `.prof` file don't match your current system.

**Solution**: Regenerate profiles by running `make profile` again on your current machine. pprof files embed absolute source paths and must be generated locally.

### No signs/hints appearing in editor

1. Verify the profile loaded successfully: `:PProfLoad` should show a confirmation message
2. Check that you're viewing one of the hottest functions:
   ```vim
   :PProfTop
   ```
3. Toggle signs and hints on:
   ```vim
   :PProfSigns on
   :PProfHints on
   ```

### Workload runs too quickly (< 30 seconds)

Your machine may be faster than expected. To increase CPU usage, edit `compute.go` and increase iteration counts:
- `newMatrix()`: increase matrix size in matrixMultiply calls
- `trigWorkload()`: increase iterations in `runComputeWorkloads()`
- `sortWorkload()`: increase n parameter

For memory profiling, edit `allocate.go`:
- Increase iteration counts in `runAllocateWorkloads()`
- Increase workload parameters (n values) in each function call

Then run `make profile` again.

### Workload runs too slowly (> 3 minutes)

Decrease iteration counts in `compute.go` and `allocate.go`, or reduce the number of passes in `runComputeWorkloads()` and `runAllocateWorkloads()` (currently 10 and 5 passes respectively).

### Signs/hints still don't appear after loading profile

1. Try `:PProfTop` to verify the profile loaded and see which functions have samples
2. Navigate to a file mentioned in the top output (e.g., `compute.go` for CPU profile)
3. Make sure you have `:set number` or another way to see line numbers
4. Check that the file is actually open in the buffer (use `:buffers` to list open buffers)
5. Try toggling signs explicitly: `:PProfSigns on` then `:PProfSigns off` and back to `on`

The signs appear as colored blocks in the sign column (left margin). If the sign column isn't visible, widen it with `:set signcolumn=yes` (or `:set signcolumn=number` to use the number column).

## Development Notes

- The demo does **not** commit `.prof` files to git (they contain absolute paths). Add to `.gitignore`:
  ```
  *.prof
  ```

- CPU and memory profiling are **sequential** (CPU profiler stops before memory workloads run) to keep profiles clean and focused

- Each workload function is designed with a **dominant hotspot** on a specific line to demonstrate the cold→hot heat gradient

## Further Reading

- [Go pprof Documentation](https://pkg.go.dev/runtime/pprof)
- [nvim-pprof GitHub Repository](https://github.com/nvim-contrib/nvim-pprof)
- [CPU Profiling Best Practices](https://golang.org/doc/diagnostics#profiling)
