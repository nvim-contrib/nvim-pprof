local util = require("pprof.util")

local M = {}

--- @class LineAnnotation
--- @field lnum integer
--- @field flat number
--- @field flat_str string
--- @field cum number
--- @field cum_str string
--- @field heat number  0.0..1.0

--- @class RoutineAnnotation
--- @field func_name string
--- @field file string
--- @field flat number
--- @field cum number
--- @field pct number
--- @field lines LineAnnotation[]

--- Parse a flat/cum value column: either "." (zero) or a value string like "120ms".
--- Returns the raw string and its parsed numeric value.
--- @param col string
--- @return string raw, number parsed
local function parse_col(col)
  if col == nil or col == "." then
    return ".", 0
  end
  local trimmed = col:match("^%s*(.-)%s*$")
  if trimmed == "" or trimmed == "." then
    return ".", 0
  end
  return trimmed, util.parse_value(trimmed)
end

--- Parse the output of `pprof -list .`.
--- @param text string
--- @return { list: table<string, RoutineAnnotation[]>, total_str: string, profile_type: string }
function M.parse(text)
  if text == nil or text == "" then
    return { list = {}, total_str = "", profile_type = "" }
  end

  local result = {}     -- keyed by file path -> RoutineAnnotation[]
  local total_str = ""
  local profile_type = ""

  local current_routine = nil  --- @type RoutineAnnotation|nil

  local function flush_routine()
    if current_routine == nil then return end

    -- Compute heat normalization per-routine: heat = flat / max_flat across lines
    local max_flat = 0
    for _, ln in ipairs(current_routine.lines) do
      if ln.flat > max_flat then
        max_flat = ln.flat
      end
    end

    for _, ln in ipairs(current_routine.lines) do
      if max_flat > 0 then
        ln.heat = ln.flat / max_flat
      else
        ln.heat = 0
      end
    end

    local file = current_routine.file
    if not result[file] then
      result[file] = {}
    end
    table.insert(result[file], current_routine)
    current_routine = nil
  end

  for line in text:gmatch("[^\n]+") do
    -- Type line: "Type: cpu" / "Type: heap" / "Type: alloc" etc.
    local ptype = line:match("^Type:%s+(.+)$")
    if ptype then
      profile_type = ptype:match("^%s*(.-)%s*$")
      goto continue
    end

    -- Total line: "Total: 1.20s"
    local total = line:match("^Total:%s+(.+)$")
    if total then
      total_str = total:match("^%s*(.-)%s*$")
      goto continue
    end

    -- ROUTINE line: "ROUTINE ======================== func.Name in /path/to/file.go"
    local func_name, file_path = line:match("^ROUTINE%s+=+%s+(.-)%s+in%s+(.+)$")
    if func_name and file_path then
      flush_routine()
      current_routine = {
        func_name = func_name:match("^%s*(.-)%s*$"),
        file = file_path:match("^%s*(.-)%s*$"),
        flat = 0,
        cum = 0,
        pct = 0,
        lines = {},
      }
      goto continue
    end

    -- Routine summary line (immediately after ROUTINE):
    -- "     120ms      1.2s (flat, cum) 85.71% of Total"
    if current_routine and #current_routine.lines == 0 then
      local flat_s, cum_s, pct_s = line:match("^%s+(%S+)%s+(%S+)%s+%(flat,%s*cum%)%s+([%d%.]+)%%%s+of%s+Total")
      if flat_s and cum_s and pct_s then
        current_routine.flat = util.parse_value(flat_s)
        current_routine.cum = util.parse_value(cum_s)
        current_routine.pct = tonumber(pct_s) or 0
        goto continue
      end
    end

    -- Annotated source line: "     120ms      1.2s     11:    result := ..."
    -- or "         .          .     10:func processData() {"
    if current_routine then
      local flat_s, cum_s, lnum_s = line:match("^%s+(%S+)%s+(%S+)%s+(%d+):")
      if flat_s and cum_s and lnum_s then
        local flat_raw, flat_num = parse_col(flat_s)
        local cum_raw, cum_num = parse_col(cum_s)
        local lnum = tonumber(lnum_s)

        if lnum then
          table.insert(current_routine.lines, {
            lnum = lnum,
            flat = flat_num,
            flat_str = flat_raw,
            cum = cum_num,
            cum_str = cum_raw,
            heat = 0,  -- filled in flush_routine
          })
        end
        goto continue
      end
    end

    ::continue::
  end

  flush_routine()

  return { list = result, total_str = total_str, profile_type = profile_type }
end

return M
