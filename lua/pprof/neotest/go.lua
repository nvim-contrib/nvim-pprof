--- Go neotest consumer that reloads the pprof profile after every test run.
---
--- Searches the neotest output directories for profile files generated during
--- the test run (e.g. via `-cpuprofile`, `-memprofile`). If none are found
--- there, falls back to auto-discovery in cwd using the configured `file`
--- patterns.
---
--- Expects tests to be run with a profiling flag, for example via neotest-go:
---
---   require("neotest").setup({
---     adapters = {
---       require("neotest-go")({
---         args = { "-cpuprofile", "cpu.prof" },
---       }),
---     },
---   })
---
--- Usage:
---   require("neotest").setup({
---     consumers = {
---       pprof = require("pprof.neotest.go"),
---     },
---   })
---
--- @type fun(client: table): table
local consumer = function(client)
  --- Search neotest result output directories for profile files.
  --- @param results table<string, neotest.Result>
  --- @return string[]  absolute paths to all profile files found
  local function find_in_results(results)
    if not results then
      return {}
    end
    local patterns = require("pprof.config").opts.file or { "cpu.prof", "mem.prof", "*.prof", "*.pprof" }
    local seen = {}
    local found = {}
    for _, result in pairs(results) do
      if result.output then
        local dir = vim.fn.fnamemodify(result.output, ":h")
        for _, pat in ipairs(patterns) do
          for _, m in ipairs(vim.fn.glob(dir .. "/" .. pat, false, true)) do
            if not seen[m] then
              seen[m] = true
              found[#found + 1] = m
            end
          end
        end
      end
    end
    return found
  end

  client.listeners.results = function(_, results, partial)
    if partial then
      return
    end
    vim.schedule(function()
      local paths = find_in_results(results)
      if #paths == 0 then
        -- Fall back to cwd auto-discovery
        require("pprof").load(nil, { silent = true })
      elseif #paths == 1 then
        require("pprof").load(paths[1])
      else
        vim.ui.select(paths, { prompt = "Select profile:" }, function(choice)
          if choice then
            require("pprof").load(choice)
          end
        end)
      end
    end)
  end

  return {}
end

return consumer
