-- Lazy-load entry point for nvim-pprof.
-- Commands are registered immediately so the plugin works without an explicit setup() call.
-- The actual module is loaded on first command use.

if vim.g.loaded_pprof then
  return
end
vim.g.loaded_pprof = true

vim.api.nvim_create_user_command("PProfLoad", function(a)
  require("pprof").load(a.args ~= "" and a.args or nil, a.bang)
end, { nargs = "?", bang = true, complete = "file" })

vim.api.nvim_create_user_command("PProfSigns", function(a)
  require("pprof").signs(a.args ~= "" and a.args or "toggle")
end, { nargs = "?" })

vim.api.nvim_create_user_command("PProfHints", function(a)
  require("pprof").hints(a.args ~= "" and a.args or "toggle")
end, { nargs = "?" })

vim.api.nvim_create_user_command("PProfTop", function(a)
  require("pprof").top(a.args ~= "" and tonumber(a.args) or nil)
end, { nargs = "?" })

vim.api.nvim_create_user_command("PProfPeek", function(a)
  require("pprof").peek(a.args ~= "" and a.args or nil)
end, { nargs = "?" })

vim.api.nvim_create_user_command("PProfNext", function()
  require("pprof").next()
end, {})

vim.api.nvim_create_user_command("PProfPrev", function()
  require("pprof").prev()
end, {})

vim.api.nvim_create_user_command("PProfLoclist", function()
  require("pprof").loclist()
end, {})

vim.api.nvim_create_user_command("PProfClear", function()
  require("pprof").clear()
end, {})
