# VHS tapes

Requires [vhs](https://github.com/charmbracelet/vhs).

```
brew install vhs
```

## Usage

Run a single tape from the repo root:

```sh
vhs doc/tapes/signs.tape
vhs doc/tapes/hints.tape
vhs doc/tapes/top.tape
vhs doc/tapes/peek.tape     # produces a PNG screenshot
```

Output files are written to `doc/tapes/output/` and committed with the repo.

## Before recording

1. Make sure the demo project has profile data: `cd doc/tapes/demo && make profile`
2. The tapes `cd doc/tapes/demo` and open `compute.go` / `cpu.prof` from there.

## Tapes

| File | Output | README placement |
|------|--------|-----------------|
| `signs.tape` | `output/signs.webp` | Below the feature list |
| `hints.tape` | `output/hints.webp` | After the Commands table |
| `top.tape` | `output/top.webp` | After the Top window keys table |
| `peek.tape` | `output/peek.png` | After the LSP code actions section |
