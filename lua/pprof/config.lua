--- @class HeatStopOpts
--- @field fg string
--- @field bg string

--- @class WindowHighlightsOpts
--- @field header table
--- @field column_header table
--- @field border table
--- @field normal table
--- @field cursor_line table
--- @field pass table
--- @field fail table

--- @class SignStateOpts
--- @field hl string  highlight group name
--- @field text string  sign column glyph

--- @class SignsOpts
--- @field cold SignStateOpts
--- @field warm SignStateOpts
--- @field hot SignStateOpts
--- @field group string
--- @field signhl boolean
--- @field numhl boolean
--- @field linehl boolean
--- @field heat_levels integer

--- @class LineHintsOpts
--- @field enabled boolean
--- @field format string
--- @field position "eol"|"right_align"|"inline"
--- @field highlight table

--- @class HighlightsOpts
--- @field cold HeatStopOpts
--- @field warm HeatStopOpts
--- @field hot HeatStopOpts

--- @class TopOpts
--- @field default_count integer
--- @field border string
--- @field width number  fraction of editor columns (0 = auto-size to content)
--- @field height number  fraction of editor lines (0 = auto-size to content)
--- @field min_flat_pct number  threshold: flat% >= this gets `fail` colour; 0 disables
--- @field window table
--- @field highlights WindowHighlightsOpts

--- @class PeekOpts
--- @field border string
--- @field width number  fraction of editor columns (0 = auto-size to content)
--- @field height number  fraction of editor lines (0 = auto-size to content)
--- @field window table
--- @field highlights WindowHighlightsOpts

--- @class AutoReloadOpts
--- @field enabled boolean
--- @field timeout_ms integer

--- @class Configuration
--- @field pprof_bin string
--- @field commands boolean
--- @field signs SignsOpts
--- @field line_hints LineHintsOpts
--- @field highlights HighlightsOpts
--- @field top TopOpts
--- @field peek PeekOpts
--- @field auto_reload AutoReloadOpts
--- @field on_load function|nil

local M = {
  --- @type Configuration
  opts = {},
}

local defaults = {
  pprof_bin = "go",
  commands = true,
  signs = {
    cold        = { hl = "PprofHeatCold", text = "▎" },
    warm        = { hl = "PprofHeatWarm", text = "▎" },
    hot         = { hl = "PprofHeatHot",  text = "▎" },
    group       = "pprof",
    signhl      = false, -- show glyph in sign column (off by default)
    numhl       = true,  -- color the line number with the heat gradient
    linehl      = false, -- color the entire line background (opt-in)
    heat_levels = 5,
  },
  line_hints = {
    enabled   = false,
    format    = "{flat} flat | {cum} cum",
    position  = "eol",
    highlight = { link = "Comment" },
  },
  highlights = {
    cold = { fg = "#3b82f6", bg = "#1e3a5f" },
    warm = { fg = "#f59e0b", bg = "#7a4f05" },
    hot  = { fg = "#ef4444", bg = "#7f1d1d" },
  },
  top = {
    default_count = 20,
    border        = "rounded",
    width         = 0.70,
    height        = 0.50,
    min_flat_pct  = 5.0,
    window        = {},
    highlights = {
      header        = { link = "Title" },
      column_header = { link = "Comment" },
      border        = { link = "FloatBorder" },
      normal        = { link = "NormalFloat" },
      cursor_line   = { link = "CursorLine" },
      pass          = { link = "Comment" },
      fail          = { link = "DiagnosticWarn" },
    },
  },
  peek = {
    border  = "rounded",
    width   = 0,
    height  = 0,
    window  = {},
    highlights = {
      header      = { link = "Title" },
      border      = { link = "FloatBorder" },
      normal      = { link = "NormalFloat" },
      cursor_line = { link = "CursorLine" },
    },
  },
  auto_reload = {
    enabled = false,
    timeout_ms = 500,
  },
  on_load = nil,
}

M.setup = function(opts)
  M.opts = vim.tbl_deep_extend("force", M.opts, defaults)
  if opts ~= nil then
    M.opts = vim.tbl_deep_extend("force", M.opts, opts)
  end

  if type(M.opts.pprof_bin) ~= "string" then
    vim.notify("pprof: pprof_bin must be a string, using default", vim.log.levels.WARN)
    M.opts.pprof_bin = defaults.pprof_bin
  end

  if M.opts.signs and M.opts.signs.heat_levels and M.opts.signs.heat_levels < 1 then
    vim.notify("pprof: heat_levels must be >= 1, clamping to 1", vim.log.levels.WARN)
    M.opts.signs.heat_levels = 1
  end
end

return M
