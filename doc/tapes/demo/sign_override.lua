-- Ensure line numbers are visible (required for numhl heat colours).
vim.opt.number = true

-- Reconfigure pprof signs with a thicker block character that renders
-- correctly in VHS recordings (▌ U+258C vs the default ▎ U+258E).
require("pprof").setup({
  signs = {
    text = "▌",
  },
})
