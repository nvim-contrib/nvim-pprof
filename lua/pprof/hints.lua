local M = {}

local config = require("pprof.config")
local cache = require("pprof.cache")

local NS = vim.api.nvim_create_namespace("pprof_hints")
local HL_GROUP = "PprofHintText"

local _visible = {} -- bufnr -> bool

local function get_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function get_buf_filepath(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end
  -- Normalize to absolute path and resolve symlinks to match cache keys
  local abs = vim.fn.fnamemodify(name, ":p")
  return vim.fn.resolve(abs)
end

local function format_hint(template, flat_str, cum_str)
  local text = template
  text = text:gsub("{flat}", flat_str)
  text = text:gsub("{cum}", cum_str)
  return text
end

--- Deduplicate line annotations by lnum, keeping the entry with the highest flat value.
--- @param annotations RoutineAnnotation[]
--- @return table<integer, LineAnnotation>
local function dedup_lines(annotations)
  local seen = {} -- lnum -> LineAnnotation
  for _, routine in ipairs(annotations) do
    if routine.lines then
      for _, line in ipairs(routine.lines) do
        local existing = seen[line.lnum]
        if existing == nil or line.flat > existing.flat then
          seen[line.lnum] = line
        end
      end
    end
  end
  return seen
end

--- @param bufnr? integer
function M.show(bufnr)
  bufnr = get_bufnr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local filepath = get_buf_filepath(bufnr)
  if not filepath then
    return
  end

  local annotations = cache.get_file(filepath)
  if not annotations or #annotations == 0 then
    return
  end

  local opts = config.opts
  local fmt = (opts.hints and opts.hints.format) or " {flat} flat | {cum} cum"

  -- Clear existing marks first
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)

  local deduped = dedup_lines(annotations)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  for lnum, line in pairs(deduped) do
    -- Skip lines with no profiling data (both flat and cum are zero)
    if line.flat == 0 and line.cum == 0 then
      goto continue
    end

    -- lnum is 1-based, extmarks use 0-based
    local row = lnum - 1
    if row >= 0 and row < line_count then
      local hint_text = format_hint(fmt, line.flat_str, line.cum_str)
      vim.api.nvim_buf_set_extmark(bufnr, NS, row, 0, {
        virt_text = { { hint_text, HL_GROUP } },
        virt_text_pos = "eol",
        hl_mode = "combine",
      })
    end

    ::continue::
  end

  _visible[bufnr] = true
end

--- @param bufnr? integer
function M.hide(bufnr)
  bufnr = get_bufnr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  _visible[bufnr] = false
end

--- @param bufnr? integer
function M.toggle(bufnr)
  bufnr = get_bufnr(bufnr)
  if M.is_visible(bufnr) then
    M.hide(bufnr)
  else
    M.show(bufnr)
  end
end

--- @param bufnr? integer
--- @return boolean
function M.is_visible(bufnr)
  bufnr = get_bufnr(bufnr)
  return _visible[bufnr] == true
end

return M
