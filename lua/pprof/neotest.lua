--- Generic neotest consumer that reloads the pprof profile after every test run.
--- Suitable for any language where the profile file is written to a known
--- location during the test run and discoverable via the configured `file`
--- patterns in cwd.
---
--- Usage:
---   require("neotest").setup({
---     consumers = {
---       pprof = require("pprof.neotest"),
---     },
---   })
---
--- @type fun(client: table): table
local consumer = function(client)
  client.listeners.results = function(_, _, partial)
    if partial then
      return
    end
    vim.schedule(function()
      require("pprof").load()
    end)
  end
  return {}
end

return consumer
