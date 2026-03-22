local M = {}

local cache = require("pprof.cache")

--- Populate the location list with all hotspot lines from the current profile.
M.populate = function()
  local profile = cache.get()
  if not profile then
    vim.notify("pprof: no profile data loaded", vim.log.levels.WARN)
    return
  end

  local all_items = {}

  for filepath, annotations in pairs(profile.list or {}) do
    for _, routine in ipairs(annotations) do
      if routine.lines then
        for _, line in ipairs(routine.lines) do
          all_items[#all_items + 1] = {
            filepath = filepath,
            lnum = line.lnum,
            flat = line.flat,
            flat_str = line.flat_str,
            cum_str = line.cum_str,
          }
        end
      end
    end
  end

  if #all_items == 0 then
    vim.notify("pprof: no hotspot lines found in profile", vim.log.levels.INFO)
    return
  end

  -- Sort by flat descending (hottest first)
  table.sort(all_items, function(a, b)
    return a.flat > b.flat
  end)

  -- Build loclist items
  local loclist_items = {}
  for _, item in ipairs(all_items) do
    loclist_items[#loclist_items + 1] = {
      filename = item.filepath,
      lnum = item.lnum,
      col = 1,
      text = item.flat_str .. " flat | " .. item.cum_str .. " cum",
    }
  end

  vim.fn.setloclist(0, {}, "r", { title = "Pprof: hotspot lines", items = loclist_items })
  vim.cmd("lopen")
end

return M
