# nvim-pprof: Honest Assessment & Production Readiness

## Is It Worth Publishing?

**Yes.** nvim-pprof fills a genuine gap — there is no other Neovim plugin for Go pprof visualization. The competitive landscape:

| Tool | Audience | pprof support |
|---|---|---|
| GoLand | JetBrains users | Built-in flame graphs, 4 profiler types |
| VS Code | VS Code users | 3-4 extensions (go-prof, GO-PPROF, EasyView) |
| `go tool pprof` | Everyone | CLI/web UI, requires context-switch |
| **Neovim** | **Growing terminal-first audience** | **Nothing — until nvim-pprof** |

Neovim's Go ecosystem has go.nvim, nvim-dap-go, gopls — but zero profiling. nvim-pprof is the first to bring `go tool pprof` data into the editor. That alone makes it publishable.

## What You Already Have (Strong Foundation)

The plugin is ~2,100 LOC across 18 modules. The architecture is clean:

- **Load pipeline**: async dual pprof invocation (list + top in parallel), parsed, cached, rendered
- **Visualization**: 5-level heat gradient in sign column, virtual text hints, two floating windows (top/peek)
- **Navigation**: `:PProfNext`/`:PProfPrev` jump between hotspots, loclist integration
- **Smart peek**: treesitter-aware function detection, LSP code action integration
- **Watch mode**: libuv-based file watcher with debounce for auto-reload
- **Graceful degradation**: TS unavailable → cword fallback; LSP client fails → silent

The demo project with realistic CPU/memory workloads is a strong onboarding tool.

## What's Compelling

1. **Zero context-switch** — see hotspots without leaving the editor
2. **Heat gradient signs** — immediate visual "where's the cost?" at a glance
3. **Peek callers/callees** — the most useful pprof query, one keystroke away
4. **Watch mode** — profile, optimize, re-run benchmark, see updated heatmap automatically
5. **LSP code action** — "Peek this function" appears in the code action menu naturally

These cover the core profiling workflow: load → scan → drill down → fix → re-profile.

## What's Missing for Production

### Must-Have Before Publishing

1. **README.md** — no top-level README exists. A plugin without a README won't get adopted. Needs: animated GIF/screenshot, feature list, install instructions (lazy.nvim/rocks.nvim), minimal setup, command reference.

2. **Minimum Neovim version declaration** — the plugin uses `vim.treesitter`, `vim.uv`, `vim.lsp.start_client` with function cmd. Needs to declare `requires nvim >= 0.10` (or 0.11 given the request ID fix).

3. **Config validation** — `pprof_bin` isn't checked for existence, `heat_levels < 1` causes division by zero. Add basic validation in `setup()`.

4. **Error messaging on missing `go tool pprof`** — if `go` isn't in PATH, the user gets a cryptic error. Should detect and tell them what's wrong.

### Should-Have (High-Impact Polish)

5. **`:PProfLoad` for HTTP endpoints** — `go tool pprof` natively supports `http://host:port/debug/pprof/profile`. Supporting URLs in `:PProfLoad` would unlock live-service profiling, which is a very common Go workflow. Minimal code change — `pprof` already accepts URLs.

6. **Flame graph or sparkline in top window** — the top window shows a table of numbers. Even a simple ASCII bar (`[========  ]`) next to each entry would make it more scannable.

7. **Multi-profile type awareness** — CPU vs memory profiles show different units and have different semantics. The plugin currently treats them identically. At minimum, detect the profile type and show it in the UI ("CPU profile" vs "Memory profile").

8. **Tests** — no tests exist. The parsers (list, top, peek) are pure-function transforms and trivially testable. Even a small test suite for parsing would prevent regressions and signal quality to users.

### Nice-to-Have (Post-Launch)

9. **Profile comparison** — load two profiles, see the diff (before/after optimization). `go tool pprof -base` supports this natively.

10. **Goroutine/blocking/mutex profiles** — pprof supports these but they need different visualization (not heat-on-source-lines). Could be a future expansion.

11. **Telescope/fzf-lua picker for top functions** — jump-to-function from the top list using a fuzzy finder.

12. **vimdoc** — `:help pprof` with proper Vim help tags. Not critical for launch but expected for mature plugins.

## Feature Priority Matrix

| Feature | Effort | Impact | Priority |
|---|---|---|---|
| README with screenshots | Medium | Critical for adoption | **P0** |
| Min nvim version + config validation | Small | Prevents bad UX | **P0** |
| Better error on missing `go` binary | Small | Prevents confusion | **P0** |
| HTTP endpoint support in `:PProfLoad` | Small | Unlocks live profiling | **P1** |
| Bar/sparkline in top window | Small | Visual polish | **P1** |
| Profile type detection (CPU/mem label) | Small | Clarity | **P1** |
| Parser tests | Medium | Confidence + quality signal | **P1** |
| Profile comparison (diff mode) | Large | Power feature | **P2** |
| vimdoc | Medium | Maturity signal | **P2** |
| Goroutine/blocking profiles | Large | Expanded scope | **P3** |

## Verdict

The core feature set — load, visualize, navigate, peek — is compelling and complete for a v0.1. No other Neovim plugin does this. The main blocker to publishing is the README (people need to see what it does). The P1 items would make it a strong v0.2.

Publish with: README + screenshots + config validation + error handling.
Then iterate on: HTTP endpoints, visual polish, tests.
