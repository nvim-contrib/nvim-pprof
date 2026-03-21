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

--- Parse the output of `pprof -peek func_name`.
---
--- Actual stdout format:
---   File: ... / Type: ... / Time: ... / Duration: ... / Showing ...
---   ------+------   (separator)
---         flat  flat%  sum%  cum  cum%  calls calls% + context
---   ------+------   (separator)
---   [~45 spaces] calls  pct% |  caller_func
---   [~5 spaces]  flat flat% sum% cum cum%  [spaces] | self_func
---   [~45 spaces] calls  pct% |  callee_func
---   ------+------   (separator)
---
--- The self entry is identified by having the flat value at a small indent (<20),
--- while callers/callees have large indent (~45 spaces) before their value.
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
  local self_found = false

  for line in text:gmatch("[^\n]+") do
    -- Separator lines: ------+------
    if line:match("^%-+%+%-+$") then goto continue end
    -- Blank lines
    if line:match("^%s*$") then goto continue end
    -- Header/meta lines
    if line:match("^File:") or line:match("^Type:") or line:match("^Time:")
        or line:match("^Duration:") or line:match("^Showing") then goto continue end
    -- Column header row (contains "flat%")
    if line:match("flat%%") then goto continue end

    -- All data lines contain "|"
    local pipe_pos = line:find("|", 1, true)
    if not pipe_pos then goto continue end

    local left  = line:sub(1, pipe_pos - 1)
    local right = line:sub(pipe_pos + 1):match("^%s*(.-)%s*$")
    if not right or right == "" then goto continue end

    -- First token = unqualified function name (used for navigation)
    local name = right:match("^(%S+)")
    if not name then goto continue end

    -- Self entry has flat data starting at small indent (~5 spaces).
    -- Caller/callee entries have large indent (~45 spaces) before calls/calls%.
    local indent = #(left:match("^(%s*)") or "")

    if indent < 20 then
      -- Self line: extract flat value and flat% (pct may be integer like "100%")
      local flat_str = left:match("^%s*(%S+)")
      local flat_pct = left:match("^%s*%S+%s+(%d+%.?%d*)%%")
      self_entry = {
        value_str = flat_str or "?",
        pct       = tonumber(flat_pct) or 0,
        name      = right,
      }
      func_name  = name
      self_found = true
    else
      -- Caller or callee: calls and calls% appear right before the pipe.
      -- PCT may be an integer ("100%") or decimal ("41.67%").
      local val_str, pct_s = left:match("(%S+)%s+(%d+%.?%d*)%%%s*$")
      local entry = {
        value_str = val_str or "?",
        pct       = tonumber(pct_s) or 0,
        name      = right,
      }
      if self_found then
        table.insert(callees, entry)
      else
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
