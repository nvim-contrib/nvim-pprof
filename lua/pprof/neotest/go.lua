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
  --- Search neotest result output directories for a profile file.
  --- @param results table<string, table>
  --- @return string|nil  absolute path to the first profile file found
  local function find_in_results(results)
    if not results then
      return nil
    end
    local patterns = require("pprof.config").opts.file or { "cpu.prof", "mem.prof", "*.prof", "*.pprof" }
    for _, result in pairs(results) do
      if result.output then
        local dir = vim.fn.fnamemodify(result.output, ":h")
        for _, pat in ipairs(patterns) do
          local matches = vim.fn.glob(dir .. "/" .. pat, false, true)
          if #matches > 0 then
            return matches[1]
          end
        end
      end
    end
    return nil
  end

  client.listeners.results = function(_, results, partial)
    if partial then
      return
    end
    vim.schedule(function()
      local path = find_in_results(results)
      if path then
        require("pprof").load(path)
      else
        -- Fall back to cwd auto-discovery
        require("pprof").load()
      end
    end)
  end

  return {}
end

return consumer
