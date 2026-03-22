local M = {}

--- Parse pprof value strings into numbers (in base SI units).
--- "120ms" -> 0.120 (seconds), "1.20s" -> 1.20, "4.2MB" -> 4404019.2 (bytes),
--- "." -> 0, "" -> 0
--- @param str string
--- @return number
function M.parse_value(str)
  if str == nil or str == "" or str == "." then
    return 0
  end

  -- Strip leading/trailing whitespace
  str = str:match("^%s*(.-)%s*$")

  if str == "" or str == "." then
    return 0
  end

  -- Match number and optional unit
  local num_str, unit = str:match("^([%d%.]+)%s*([%a%u%p]*)$")
  if not num_str then
    return 0
  end

  local num = tonumber(num_str)
  if not num then
    return 0
  end

  unit = unit or ""

  -- Time units -> seconds
  if unit == "ns" then
    return num * 1e-9
  elseif unit == "us" or unit == "μs" or unit == "\xce\xbcs" then
    return num * 1e-6
  elseif unit == "ms" then
    return num * 1e-3
  elseif unit == "s" then
    return num
  elseif unit == "min" then
    return num * 60

    -- Memory units -> bytes
  elseif unit == "B" then
    return num
  elseif unit == "kB" or unit == "KB" then
    return num * 1024
  elseif unit == "MB" then
    return num * 1024 * 1024
  elseif unit == "GB" then
    return num * 1024 * 1024 * 1024
  elseif unit == "TB" then
    return num * 1024 * 1024 * 1024 * 1024

    -- Dimensionless
  elseif unit == "samples" or unit == "count" or unit == "" then
    return num
  end

  -- Unknown unit: return raw number
  return num
end

--- Format a number back to a human-readable string with the given unit.
--- @param num number
--- @param unit string
--- @return string
function M.format_value(num, unit)
  if num == nil then
    num = 0
  end
  unit = unit or ""

  if unit == "ns" then
    return string.format("%.0fns", num * 1e9)
  elseif unit == "us" or unit == "μs" then
    return string.format("%.0fμs", num * 1e6)
  elseif unit == "ms" then
    return string.format("%.0fms", num * 1e3)
  elseif unit == "s" then
    return string.format("%.2fs", num)
  elseif unit == "min" then
    return string.format("%.2fmin", num / 60)
  elseif unit == "B" then
    return string.format("%.0fB", num)
  elseif unit == "kB" or unit == "KB" then
    return string.format("%.2fkB", num / 1024)
  elseif unit == "MB" then
    return string.format("%.2fMB", num / (1024 * 1024))
  elseif unit == "GB" then
    return string.format("%.2fGB", num / (1024 * 1024 * 1024))
  elseif unit == "TB" then
    return string.format("%.2fTB", num / (1024 * 1024 * 1024 * 1024))
  else
    if num == math.floor(num) then
      return string.format("%.0f", num)
    else
      return string.format("%.4g", num)
    end
  end
end

--- Parse a hex color string "#rrggbb" into r, g, b components (0-255).
--- @param hex string
--- @return number, number, number
local function hex_to_rgb(hex)
  hex = hex:gsub("^#", "")
  local r = tonumber(hex:sub(1, 2), 16) or 0
  local g = tonumber(hex:sub(3, 4), 16) or 0
  local b = tonumber(hex:sub(5, 6), 16) or 0
  return r, g, b
end

--- Format r, g, b components (0-255) into "#rrggbb".
--- @param r number
--- @param g number
--- @param b number
--- @return string
local function rgb_to_hex(r, g, b)
  return string.format("#%02x%02x%02x", math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5))
end

--- Linear interpolation between two hex color strings.
--- @param c1 string  e.g. "#3b82f6"
--- @param c2 string  e.g. "#ef4444"
--- @param t number   0.0 = c1, 1.0 = c2
--- @return string    hex color string
function M.lerp_color(c1, c2, t)
  t = math.max(0, math.min(1, t))
  local r1, g1, b1 = hex_to_rgb(c1)
  local r2, g2, b2 = hex_to_rgb(c2)
  local r = r1 + (r2 - r1) * t
  local g = g1 + (g2 - g1) * t
  local b = b1 + (b2 - b1) * t
  return rgb_to_hex(r, g, b)
end

--- Map normalized heat (0.0-1.0) to a discrete level (1..levels).
--- @param heat number  0.0 to 1.0
--- @param levels integer
--- @return integer
function M.heat_to_level(heat, levels)
  if levels <= 1 then
    return 1
  end
  heat = math.max(0, math.min(1, heat))
  local level = math.floor(heat * (levels - 1) + 0.5) + 1
  return math.max(1, math.min(levels, level))
end

--- Escape special Lua pattern characters in a string.
--- @param str string
--- @return string
function M.escape_pattern(str)
  return (str:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1"))
end

return M
