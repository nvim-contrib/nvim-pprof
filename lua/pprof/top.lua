local M = {}

local cache = require("pprof.cache")
local config = require("pprof.config")
local util = require("pprof.util")

local _state = {
  bufnr = nil,
  win = nil,
  entries = nil, -- current sorted entries
  total_str = nil,
  profile_type = nil,
}

local HEADER_HL = "PprofTopHeader"
local COLHDR_HL = "PprofTopColHeader"
local BAR_WIDTH = 10

--- Define highlight groups for the top window from config.
local function setup_highlights()
  local top_hl = (config.opts.top and config.opts.top.highlights) or {}
  vim.api.nvim_set_hl(0, HEADER_HL, top_hl.header or { link = "Title" })
  vim.api.nvim_set_hl(0, COLHDR_HL, top_hl.column_header or { link = "Comment" })
  vim.api.nvim_set_hl(0, "PprofTopBorder", top_hl.border or { link = "FloatBorder" })
  vim.api.nvim_set_hl(0, "PprofTopNormal", top_hl.normal or { link = "NormalFloat" })
  vim.api.nvim_set_hl(0, "PprofTopCursorLine", top_hl.cursor_line or { link = "CursorLine" })
  vim.api.nvim_set_hl(0, "PprofTopPass", top_hl.pass or { link = "Comment" })
  vim.api.nvim_set_hl(0, "PprofTopFail", top_hl.fail or { link = "DiagnosticWarn" })
end

--- Returns the highlight group for the flat% column based on min_flat_pct threshold.
--- Returns nil when threshold is 0 (disabled).
--- @param flat_pct number
--- @return string|nil
local function get_flat_hl_group(flat_pct)
  local min_pct = (config.opts.top and config.opts.top.min_flat_pct) or 5.0
  if min_pct == 0 then
    return nil
  end
  return flat_pct >= min_pct and "PprofTopFail" or "PprofTopPass"
end

--- Apply a list of highlights to a buffer.
--- @param bufnr integer
--- @param highlights {hl_group:string, line:integer, col_start:integer, col_end:integer}[]
local function apply_highlights(bufnr, highlights)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(bufnr, -1, hl.hl_group, hl.line, hl.col_start, hl.col_end)
  end
end

--- Build a fixed-width ASCII bar representing a 0–1 heat value.
--- @param heat number  0.0..1.0
--- @return string  exactly BAR_WIDTH chars
local function make_bar(heat)
  local filled = math.floor(heat * BAR_WIDTH + 0.5)
  return string.rep("█", filled) .. string.rep("░", BAR_WIDTH - filled)
end

--- Format a single row for a TopEntry, function name first.
--- @param entry TopEntry
--- @param name_w integer  width of the function name column
--- @param max_pct number  highest flat_pct in the list (for bar normalisation)
--- @return string
local function format_row(entry, name_w, max_pct)
  local heat = max_pct > 0 and (entry.flat_pct / max_pct) or 0
  return string.format(
    "  %-" .. name_w .. "s  %8s  %6.2f%%  %6.2f%%  %8s  %6.2f%%  %s",
    entry.func_name,
    entry.flat_str,
    entry.flat_pct,
    entry.sum_pct,
    entry.cum_str,
    entry.cum_pct,
    make_bar(heat)
  )
end

--- Build display lines and highlights from entries.
--- @param entries TopEntry[]
--- @param total_str string
--- @param profile_type string
--- @return string[], {hl_group:string, line:integer, col_start:integer, col_end:integer}[]
local function build_lines(entries, total_str, profile_type)
  local name_w = #"function"
  for _, entry in ipairs(entries) do
    if #entry.func_name > name_w then
      name_w = #entry.func_name
    end
  end

  local levels = (config.opts.signs and config.opts.signs.heat_levels) or 5
  local max_pct = 0
  for _, entry in ipairs(entries) do
    if entry.flat_pct > max_pct then
      max_pct = entry.flat_pct
    end
  end

  -- flat% column byte offset: 2 indent + name_w + 2 sep + 8 flat_str + 2 sep = name_w+14
  -- flat% column byte width:  "%6.2f%%" renders to 7 chars (e.g. " 14.89%")
  local flat_col = name_w + 14
  local flat_col_end = flat_col + 7

  local lines = {}
  local highlights = {}

  local type_label = (profile_type and profile_type ~= "") and (" [" .. profile_type .. "]") or ""
  lines[#lines + 1] = string.format("Top Functions%s  (total: %s)", type_label, total_str)
  table.insert(highlights, { hl_group = HEADER_HL, line = 0, col_start = 0, col_end = -1 })

  lines[#lines + 1] = string.format(
    "  %-" .. name_w .. "s  %8s  %6s   %6s   %8s  %6s  %-" .. BAR_WIDTH .. "s",
    "function",
    "flat",
    "flat%",
    "sum%",
    "cum",
    "cum%",
    "bar"
  )
  table.insert(highlights, { hl_group = COLHDR_HL, line = 1, col_start = 0, col_end = -1 })

  lines[#lines + 1] = string.rep("─", vim.fn.strdisplaywidth(lines[2]))

  for i, entry in ipairs(entries) do
    local row = i + 2 -- 0-based: title(0), colhdr(1), sep(2), data(3+)
    lines[#lines + 1] = format_row(entry, name_w, max_pct)

    -- Whole-row heat gradient, normalised against the hottest entry
    local heat = max_pct > 0 and (entry.flat_pct / max_pct) or 0
    local level = util.heat_to_level(heat, levels)
    table.insert(highlights, { hl_group = "PprofHeat" .. level, line = row, col_start = 0, col_end = -1 })

    -- flat% column: pass/fail based on min_flat_pct threshold
    local col_hl = get_flat_hl_group(entry.flat_pct)
    if col_hl then
      table.insert(highlights, { hl_group = col_hl, line = row, col_start = flat_col, col_end = flat_col_end })
    end
  end

  return lines, highlights
end

--- Compute float window dimensions and position.
--- @param lines string[]
--- @return table
local function float_config(lines)
  local max_w = 0
  for _, l in ipairs(lines) do
    local w = vim.fn.strdisplaywidth(l)
    if w > max_w then
      max_w = w
    end
  end

  local top_cfg = config.opts.top or {}

  local width = (top_cfg.width and top_cfg.width > 0) and math.floor(vim.o.columns * top_cfg.width)
      or math.max(25, math.min(max_w + 2, vim.o.columns - 4))
  local height = (top_cfg.height and top_cfg.height > 0) and math.floor(vim.o.lines * top_cfg.height)
      or math.max(3, math.min(#lines, vim.o.lines - 4))

  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  return vim.tbl_extend("force", {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = top_cfg.border or "rounded",
    style = "minimal",
    noautocmd = false,
  }, top_cfg.window or {})
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

  -- func_name is the first token (left-aligned in column 0)
  local func_name = vim.trim(line):match("^(%S+)")
  if not func_name then
    return
  end

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
      if found_file then
        break
      end
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
  local lines, highlights = build_lines(entries, _state.total_str, _state.profile_type)

  vim.bo[_state.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(_state.bufnr, 0, -1, false, lines)
  vim.bo[_state.bufnr].modifiable = false

  apply_highlights(_state.bufnr, highlights)

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
--- @param profile_type? string
function M.show(entries, total_str, profile_type)
  -- Close existing window if open
  M.close()

  setup_highlights()

  _state.total_str = total_str
  _state.entries = entries
  _state.profile_type = profile_type or ""

  local lines, highlights = build_lines(entries, total_str, _state.profile_type)

  -- Create scratch buffer
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].filetype = "pprof-top"

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false

  apply_highlights(bufnr, highlights)

  -- Open float
  local cfg = float_config(lines)
  local win = vim.api.nvim_open_win(bufnr, true, cfg)

  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].wrap = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].winhighlight = "Normal:PprofTopNormal,FloatBorder:PprofTopBorder,CursorLine:PprofTopCursorLine"

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
    if not _state.entries then
      return
    end
    local sorted = vim.deepcopy(_state.entries)
    table.sort(sorted, function(a, b)
      return a.flat_pct > b.flat_pct
    end)
    redraw(sorted)
  end)

  map("sc", function()
    if not _state.entries then
      return
    end
    local sorted = vim.deepcopy(_state.entries)
    table.sort(sorted, function(a, b)
      return a.cum_pct > b.cum_pct
    end)
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
