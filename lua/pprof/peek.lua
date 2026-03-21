local M = {}

local cache  = require("pprof.cache")
local config = require("pprof.config")

local _state = {
  bufnr = nil,
  win = nil,
  lines = nil, -- raw display lines for cursor-based navigation
}

local SEP = string.rep("─", 40)

local function close_win()
  if _state.win and vim.api.nvim_win_is_valid(_state.win) then
    vim.api.nvim_win_close(_state.win, true)
  end
  _state.win = nil
  _state.bufnr = nil
  _state.lines = nil
end

--- Build display lines from PeekData.
--- @param peek_data PeekData
--- @return string[]
local function build_lines(peek_data)
  local lines = {}

  lines[#lines + 1] = "Callers:"
  if peek_data.callers and #peek_data.callers > 0 then
    for _, caller in ipairs(peek_data.callers) do
      lines[#lines + 1] = string.format("  %s  %s (%.2f%%)", caller.name, caller.value_str, caller.pct)
    end
  else
    lines[#lines + 1] = "  (none)"
  end

  lines[#lines + 1] = SEP

  local self_str = peek_data.self and peek_data.self.value_str or "?"
  lines[#lines + 1] = string.format("→ %s  %s [self]", peek_data.func_name, self_str)

  lines[#lines + 1] = SEP

  lines[#lines + 1] = "Callees:"
  if peek_data.callees and #peek_data.callees > 0 then
    for _, callee in ipairs(peek_data.callees) do
      lines[#lines + 1] = string.format("  %s  %s (%.2f%%)", callee.name, callee.value_str, callee.pct)
    end
  else
    lines[#lines + 1] = "  (none)"
  end

  return lines
end

--- Compute float window config near cursor.
--- @param lines string[]
--- @return table
local function float_config(lines)
  local max_w = 0
  for _, l in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(l)
    if w > max_w then max_w = w end
  end

  local peek_cfg = config.opts.peek or {}

  local width  = (peek_cfg.width  and peek_cfg.width  > 0)
    and math.floor(vim.o.columns * peek_cfg.width)
    or  math.max(25, math.min(max_w + 2, vim.o.columns - 4))
  local height = (peek_cfg.height and peek_cfg.height > 0)
    and math.floor(vim.o.lines * peek_cfg.height)
    or  math.max(3, math.min(#lines, vim.o.lines - 6))

  return vim.tbl_extend("force", {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    border = peek_cfg.border or "rounded",
    style = "minimal",
    noautocmd = false,
  }, peek_cfg.window or {})
end

--- Navigate to the function name found on the line under cursor.
local function jump_to_func()
  if not _state.win or not vim.api.nvim_win_is_valid(_state.win) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(_state.win)
  local line = vim.api.nvim_buf_get_lines(_state.bufnr, cursor[1] - 1, cursor[1], false)[1]
  if not line then
    return
  end

  -- Extract a function name: strip leading arrow/spaces, grab first token
  local stripped = line:gsub("^%s*→?%s*", "")
  local func_name = stripped:match("^(%S+)")
  if not func_name or func_name == "(none)" or func_name == "Callers:" or func_name == "Callees:" then
    return
  end
  -- Strip trailing separator characters
  func_name = func_name:gsub("[─]+$", "")
  if func_name == "" then
    return
  end

  local profile = cache.get()
  if not profile then
    return
  end

  local found_file, found_lnum
  if profile.list then
    for filepath, routines in pairs(profile.list) do
      for _, routine in ipairs(routines) do
        if routine.func_name == func_name and routine.file then
          found_file = routine.file
          if routine.lines and #routine.lines > 0 then
            found_lnum = routine.lines[1].lnum
          else
            found_lnum = 1
          end
          break
        end
      end
      if found_file then break end
    end
  end

  if not found_file then
    vim.notify("pprof: no source found for " .. func_name, vim.log.levels.WARN)
    return
  end

  close_win()
  vim.cmd.edit(vim.fn.fnameescape(found_file))
  if found_lnum then
    vim.api.nvim_win_set_cursor(0, { found_lnum, 0 })
  end
end

--- @param peek_data PeekData
function M.show(peek_data)
  M.close()

  local lines = build_lines(peek_data)
  _state.lines = lines

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "pprof-peek"

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false

  local cfg = float_config(lines)
  local win = vim.api.nvim_open_win(bufnr, true, cfg)

  local peek_hl = (config.opts.peek and config.opts.peek.highlights) or {}
  vim.api.nvim_set_hl(0, "PprofPeekBorder",     peek_hl.border      or { link = "FloatBorder" })
  vim.api.nvim_set_hl(0, "PprofPeekNormal",     peek_hl.normal      or { link = "NormalFloat" })
  vim.api.nvim_set_hl(0, "PprofPeekCursorLine", peek_hl.cursor_line or { link = "CursorLine" })

  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].wrap = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].winhighlight = "Normal:PprofPeekNormal,FloatBorder:PprofPeekBorder,CursorLine:PprofPeekCursorLine"

  _state.bufnr = bufnr
  _state.win = win

  local function map(key, fn)
    vim.keymap.set("n", key, fn, { buffer = bufnr, nowait = true, silent = true })
  end

  map("q", M.close)
  map("<Esc>", M.close)
  map("<CR>", jump_to_func)

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = bufnr,
    once = true,
    callback = function()
      M.close()
    end,
  })
end

function M.close()
  close_win()
end

return M
