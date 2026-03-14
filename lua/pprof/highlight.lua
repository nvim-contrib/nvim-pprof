local util = require("pprof.util")

local M = {}

-- Gradient stops: cold (blue) -> warm (amber) -> hot (red)
local COLOR_COLD = "#3b82f6"
local COLOR_WARM = "#f59e0b"
local COLOR_HOT  = "#ef4444"

-- Background variants (darker/muted for sign column)
local BG_COLD = "#1e3a5f"
local BG_WARM = "#7a4f05"
local BG_HOT  = "#7f1d1d"

local HINT_COLOR = "#6b7280"

--- Compute the foreground and background gradient color for a given level.
--- @param level integer  1-based
--- @param levels integer total levels
--- @return string fg, string bg
local function gradient_colors(level, levels)
  if levels <= 1 then
    return COLOR_HOT, BG_HOT
  end
  -- Normalized 0..1
  local t = (level - 1) / (levels - 1)

  local fg, bg
  if t <= 0.5 then
    local t2 = t * 2
    fg = util.lerp_color(COLOR_COLD, COLOR_WARM, t2)
    bg = util.lerp_color(BG_COLD, BG_WARM, t2)
  else
    local t2 = (t - 0.5) * 2
    fg = util.lerp_color(COLOR_WARM, COLOR_HOT, t2)
    bg = util.lerp_color(BG_WARM, BG_HOT, t2)
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

    -- Sign column highlight (fg text on colored background)
    vim.api.nvim_set_hl(0, "PprofHeatSign" .. i, { fg = fg, bg = bg })
  end

  -- Subtle gray for virtual hint text
  vim.api.nvim_set_hl(0, "PprofHintText", { fg = HINT_COLOR })
end

return M
