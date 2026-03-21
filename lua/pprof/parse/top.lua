local M = {}

--- @class TopEntry
--- @field flat_str string
--- @field flat_pct number
--- @field sum_pct number
--- @field cum_str string
--- @field cum_pct number
--- @field func_name string

--- Parse the output of `pprof -top`.
--- @param text string
--- @return TopEntry[]
function M.parse(text)
  if text == nil or text == "" then
    return {}
  end

  local entries = {}
  local past_header = false

  for line in text:gmatch("[^\n]+") do
    -- Detect the column header line: "      flat  flat%   sum%        cum   cum%"
    if not past_header then
      if line:match("flat%%") and line:match("cum%%") and line:match("sum%%") then
        past_header = true
      end
      goto continue
    end

    -- Skip blank lines
    if line:match("^%s*$") then
      goto continue
    end

    -- Data row: "     800ms 66.67% 66.67%      1.2s   100%  main.compute"
    -- Fields: flat_str flat_pct% sum_pct% cum_str cum_pct% func_name
    local flat_str, flat_pct_s, sum_pct_s, cum_str, cum_pct_s, func_name =
      line:match("^%s+(%S+)%s+([%d%.]+)%%%s+([%d%.]+)%%%s+(%S+)%s+([%d%.]+)%%%s+(%S+)%s*$")

    if flat_str and func_name then
      table.insert(entries, {
        flat_str  = flat_str,
        flat_pct  = tonumber(flat_pct_s) or 0,
        sum_pct   = tonumber(sum_pct_s) or 0,
        cum_str   = cum_str,
        cum_pct   = tonumber(cum_pct_s) or 0,
        func_name = func_name,
      })
    end

    ::continue::
  end

  return entries
end

return M
