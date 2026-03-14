local M = {}

local cache = require("pprof.cache")

local _state = {
  bufnr = nil,
  win = nil,
  entries = nil, -- current sorted entries
  total_str = nil,
}

local HEADER_HL = "PprofTopHeader"
local COLHDR_HL = "PprofTopColHeader"

--- Format a single row for a TopEntry, aligned to fixed columns.
--- Columns: flat(8) flat%(7) sum%(6) cum(8) cum%(7) function
--- @param entry TopEntry
--- @return string
local function format_row(entry)
  return string.format(
    "  %8s  %6.2f%%  %6.2f%%  %8s  %6.2f%%  %s",
    entry.flat_str,
    entry.flat_pct,
    entry.sum_pct,
    entry.cum_str,
    entry.cum_pct,
    entry.func_name
  )
end

--- Build display lines from entries.
--- @param entries TopEntry[]
--- @param total_str string
--- @return string[]
local function build_lines(entries, total_str)
  local lines = {}
  lines[#lines + 1] = string.format("Top Functions (total: %s)", total_str)
  lines[#lines + 1] = string.format(
    "  %8s  %6s   %6s   %8s  %6s   %s",
    "flat", "flat%", "sum%", "cum", "cum%", "function"
  )
  lines[#lines + 1] = string.rep("─", 70)
  for _, entry in ipairs(entries) do
    lines[#lines + 1] = format_row(entry)
  end
  return lines
end

--- Compute float window dimensions and position.
--- @param lines string[]
--- @return table
local function float_config(lines)
  local max_w = 0
  for _, l in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(l)
    if w > max_w then max_w = w end
  end

  local width = math.max(25, math.min(max_w + 2, vim.o.columns - 4))
  local height = math.max(3, math.min(#lines, vim.o.lines - 4))

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  return {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
    noautocmd = false,
  }
end

local function close_win()
  if _state.win and vim.api.nvim_win_is_valid(_state.win) then
    vim.api.nvim_win_close(_state.win, true)
  end
  _state.win = nil
  _state.bufnr = nil
end

--- Navigate to the function under cursor (parses func_name from the current line).
local function jump_to_func()
  if not _state.win or not vim.api.nvim_win_is_valid(_state.win) then
    return
  end

  local bufnr = _state.bufnr
  local cursor = vim.api.nvim_win_get_cursor(_state.win)
  local line = vim.api.nvim_buf_get_lines(bufnr, cursor[1] - 1, cursor[1], false)[1]
  if not line then
    return
  end

  -- func_name is the last whitespace-separated token
  local func_name = line:match("%S+%s*$")
  if not func_name then
    return
  end
  func_name = vim.trim(func_name)

  -- Look up in cache for a matching file/routine
  local profile = cache.get()
  if not profile then
    return
  end

  -- Iterate cache.list (keyed by filepath -> RoutineAnnotation[]) to find a match
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

--- Redraw the buffer with new sorted entries.
local function redraw(entries)
  if not _state.bufnr or not vim.api.nvim_buf_is_valid(_state.bufnr) then
    return
  end
  _state.entries = entries
  local lines = build_lines(entries, _state.total_str)

  vim.bo[_state.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(_state.bufnr, 0, -1, false, lines)
  vim.bo[_state.bufnr].modifiable = false

  -- Reapply highlights
  vim.api.nvim_buf_add_highlight(_state.bufnr, -1, HEADER_HL, 0, 0, -1)
  vim.api.nvim_buf_add_highlight(_state.bufnr, -1, COLHDR_HL, 1, 0, -1)

  -- Resize window to fit new content if still valid
  if _state.win and vim.api.nvim_win_is_valid(_state.win) then
    local cfg = float_config(lines)
    vim.api.nvim_win_set_config(_state.win, {
      relative = cfg.relative,
      row = cfg.row,
      col = cfg.col,
      width = cfg.width,
      height = cfg.height,
    })
  end
end

--- @param entries TopEntry[]
--- @param total_str string
function M.show(entries, total_str)
  -- Close existing window if open
  M.close()

  _state.total_str = total_str
  _state.entries = entries

  local lines = build_lines(entries, total_str)

  -- Create scratch buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "pprof-top"

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false

  -- Highlight header rows
  vim.api.nvim_buf_add_highlight(bufnr, -1, HEADER_HL, 0, 0, -1)
  vim.api.nvim_buf_add_highlight(bufnr, -1, COLHDR_HL, 1, 0, -1)

  -- Open float
  local cfg = float_config(lines)
  local win = vim.api.nvim_open_win(bufnr, true, cfg)

  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].wrap = false
  vim.wo[win].signcolumn = "no"

  _state.bufnr = bufnr
  _state.win = win

  -- Keymaps
  local function map(key, fn)
    vim.keymap.set("n", key, fn, { buffer = bufnr, nowait = true, silent = true })
  end

  map("q", M.close)
  map("<Esc>", M.close)
  map("<CR>", jump_to_func)

  map("sf", function()
    if not _state.entries then return end
    local sorted = vim.deepcopy(_state.entries)
    table.sort(sorted, function(a, b) return a.flat_pct > b.flat_pct end)
    redraw(sorted)
  end)

  map("sc", function()
    if not _state.entries then return end
    local sorted = vim.deepcopy(_state.entries)
    table.sort(sorted, function(a, b) return a.cum_pct > b.cum_pct end)
    redraw(sorted)
  end)

  -- Auto-close on BufLeave
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

--- @return boolean
function M.is_open()
  return _state.win ~= nil and vim.api.nvim_win_is_valid(_state.win)
end

return M
