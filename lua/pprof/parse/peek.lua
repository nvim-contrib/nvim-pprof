local M = {}

--- @class PeekEntry
--- @field value_str string
--- @field pct number
--- @field name string

--- @class PeekData
--- @field func_name string
--- @field self PeekEntry|nil
--- @field callees PeekEntry[]  functions this function calls
--- @field callers PeekEntry[]  functions that call this function

--- Parse a value/pct line like "  120ms (10.00%)  |  main.compute"
--- @param line string
--- @return PeekEntry|nil
local function parse_peek_entry(line)
  local val_str, pct_s, name = line:match("^%s*(%S+)%s+%(([%d%.]+)%%)%s+|%s+(.-)%s*$")
  if val_str and pct_s and name then
    return {
      value_str = val_str,
      pct       = tonumber(pct_s) or 0,
      name      = name,
    }
  end
  return nil
end

--- Parse the output of `pprof -peek func_name`.
--- @param text string
--- @return PeekData
function M.parse(text)
  if text == nil or text == "" then
    return { func_name = "", self = nil, callees = {}, callers = {} }
  end

  local func_name = ""
  local self_entry = nil
  local callees = {}
  local callers = {}

  -- State: "header" -> "before_sep" -> "after_sep"
  local state = "header"

  local lines = {}
  for line in text:gmatch("[^\n]+") do
    lines[#lines + 1] = line
  end

  local i = 1

  -- First non-blank line is the function name
  while i <= #lines do
    local line = lines[i]
    i = i + 1
    if not line:match("^%s*$") then
      func_name = line:match("^%s*(.-)%s*$")
      state = "before_sep"
      break
    end
  end

  -- Remaining lines: entries before "----" separator are callees (or self),
  -- entries after separator are callers.
  while i <= #lines do
    local line = lines[i]
    i = i + 1

    -- Separator line
    if line:match("^%s*%-%-%-%-+%s*$") then
      state = "after_sep"
      goto continue
    end

    -- Skip blank lines
    if line:match("^%s*$") then
      goto continue
    end

    local entry = parse_peek_entry(line)
    if entry then
      if state == "before_sep" then
        -- The "self" entry is identified by name == "self"
        if entry.name == "self" then
          self_entry = entry
        else
          table.insert(callees, entry)
        end
      elseif state == "after_sep" then
        table.insert(callers, entry)
      end
    end

    ::continue::
  end

  return {
    func_name = func_name,
    self      = self_entry,
    callees   = callees,
    callers   = callers,
  }
end

return M
