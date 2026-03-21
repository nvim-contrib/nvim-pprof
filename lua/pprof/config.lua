local M = {}

local defaults = {
	pprof_bin = "go",
	signs = {
		heat_levels = 5,
		priority    = 10,
		signhl      = false, -- show glyph in sign column (off by default; coverage owns sign col)

		numhl       = true,  -- color the line number with the heat gradient
		linehl      = false, -- color the entire line background (opt-in)
	},
	hints = {
		enabled = false,
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
