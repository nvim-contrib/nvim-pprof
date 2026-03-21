local util   = require("pprof.util")
local config = require("pprof.config")

local M = {}

--- Compute the foreground and background gradient color for a given level.
--- @param level integer  1-based
--- @param levels integer total levels
--- @return string fg, string bg
local function gradient_colors(level, levels)
  local hl  = config.opts.highlights or {}
  local cold = hl.cold or { fg = "#3b82f6", bg = "#1e3a5f" }
  local warm = hl.warm or { fg = "#f59e0b", bg = "#7a4f05" }
  local hot  = hl.hot  or { fg = "#ef4444", bg = "#7f1d1d" }

  if levels <= 1 then
    return hot.fg, hot.bg
  end
  -- Normalized 0..1
  local t = (level - 1) / (levels - 1)

  local fg, bg
  if t <= 0.5 then
    local t2 = t * 2
    fg = util.lerp_color(cold.fg, warm.fg, t2)
    bg = util.lerp_color(cold.bg, warm.bg, t2)
  else
    local t2 = (t - 0.5) * 2
    fg = util.lerp_color(warm.fg, hot.fg, t2)
    bg = util.lerp_color(warm.bg, hot.bg, t2)
  end

  return fg, bg
end

--- Define all pprof highlight groups.
--- @param heat_levels integer
function M.setup(heat_levels)
  heat_levels = heat_levels or 5

  for i = 1, heat_levels do
    local fg, bg = gradient_colors(i, heat_levels)

    -- Text highlight (for virtual text / line annotations)
    vim.api.nvim_set_hl(0, "PprofHeat" .. i, { fg = fg })

    -- Sign column glyph highlight
    vim.api.nvim_set_hl(0, "PprofHeatSign" .. i, { fg = fg, bg = bg })

    -- Line number highlight (extmark number_hl_group)
    vim.api.nvim_set_hl(0, "PprofHeatNumber" .. i, { fg = fg, bold = true })

    -- Full line background highlight (extmark line_hl_group, opt-in)
    vim.api.nvim_set_hl(0, "PprofHeatLine" .. i, { bg = bg })
  end

  -- Named anchor groups for cold / warm / hot
  local hl    = config.opts.highlights or {}
  local signs = config.opts.signs or {}
  local cold  = hl.cold or { fg = "#3b82f6", bg = "#1e3a5f" }
  local warm  = hl.warm or { fg = "#f59e0b", bg = "#7a4f05" }
  local hot   = hl.hot  or { fg = "#ef4444", bg = "#7f1d1d" }

  vim.api.nvim_set_hl(0, (signs.cold and signs.cold.hl) or "PprofHeatCold", { fg = cold.fg, bg = cold.bg })
  vim.api.nvim_set_hl(0, (signs.warm and signs.warm.hl) or "PprofHeatWarm", { fg = warm.fg, bg = warm.bg })
  vim.api.nvim_set_hl(0, (signs.hot  and signs.hot.hl)  or "PprofHeatHot",  { fg = hot.fg,  bg = hot.bg  })

  -- Hint text highlight
  local hint_hl = (config.opts.line_hints and config.opts.line_hints.highlight) or { link = "Comment" }
  vim.api.nvim_set_hl(0, "PprofHintText", hint_hl)
end

return M
