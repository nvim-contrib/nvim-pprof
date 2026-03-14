local M = {}

local defaults = {
  pprof_bin = "go",
  signs = {
    enabled = true,
    heat_levels = 5,
    priority = 10,
  },
  hints = {
    enabled = true,
    format = "{flat} flat | {cum} cum",
  },
  top = {
    default_count = 20,
  },
  watch = {
    enabled = false,
    debounce_ms = 500,
  },
  on_load = nil,
}

M.opts = vim.deepcopy(defaults)

function M.setup(user_opts)
  M.opts = vim.tbl_deep_extend("force", defaults, user_opts or {})
end

return M
