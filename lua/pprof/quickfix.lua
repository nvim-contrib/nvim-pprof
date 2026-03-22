local M = {}

local cache = require("pprof.cache")
local util = require("pprof.util")

--- Populate the quickfix list with one entry per profiled file.
M.populate = function()
  local profile = cache.get()
  if not profile then
    vim.notify("pprof: no profile data loaded", vim.log.levels.WARN)
    return
  end

  local files = profile.list or {}
  local rows = {}

  for filepath, annotations in pairs(files) do
    local total_flat = 0
    local total_cum = 0
    local hot_lnum = 1
    local max_flat = 0

    for _, routine in ipairs(annotations) do
      total_flat = total_flat + routine.flat
      total_cum = total_cum + routine.cum
      if routine.lines then
        for _, ln in ipairs(routine.lines) do
          if ln.flat > max_flat then
            max_flat = ln.flat
            hot_lnum = ln.lnum
          end
        end
      end
    end

    if total_flat > 0 or total_cum > 0 then
      rows[#rows + 1] = {
        filename = filepath,
        lnum = hot_lnum,
        flat = total_flat,
        cum = total_cum,
      }
    end
  end

  if #rows == 0 then
    vim.notify("pprof: no hotspot files found in profile", vim.log.levels.INFO)
    return
  end

  table.sort(rows, function(a, b)
    return a.flat > b.flat
  end)

  -- Detect the unit from total_str for consistent formatting
  local unit = (profile.total_str or ""):match("[%a]+$") or ""

  local items = {}
  for _, row in ipairs(rows) do
    local flat_str = util.format_value(row.flat, unit)
    local cum_str = util.format_value(row.cum, unit)
    items[#items + 1] = {
      filename = row.filename,
      lnum = row.lnum,
      col = 0,
      text = flat_str .. " flat | " .. cum_str .. " cum",
    }
  end

  vim.fn.setqflist({}, "r", { title = "pprof", items = items })
  vim.cmd("copen")
end

return M
