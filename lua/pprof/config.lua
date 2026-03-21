local M = {}

local defaults = {
	pprof_bin = "go",
	commands = true,
	signs = {
		heat_levels = 5,
		text        = "▎",   -- sign column glyph (U+258E); override with "▌" for thick rendering
		signhl      = false, -- show glyph in sign column (off by default)
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
	auto_reload = {
		enabled = false,
		timeout_ms = 500,
	},
	on_load = nil,
}

M.opts = vim.deepcopy(defaults)

function M.setup(user_opts)
	M.opts = vim.tbl_deep_extend("force", defaults, user_opts or {})

	if type(M.opts.pprof_bin) ~= "string" then
		vim.notify("pprof: pprof_bin must be a string, using default", vim.log.levels.WARN)
		M.opts.pprof_bin = defaults.pprof_bin
	end

	if M.opts.signs and M.opts.signs.heat_levels and M.opts.signs.heat_levels < 1 then
		vim.notify("pprof: heat_levels must be >= 1, clamping to 1", vim.log.levels.WARN)
		M.opts.signs.heat_levels = 1
	end
end

return M
