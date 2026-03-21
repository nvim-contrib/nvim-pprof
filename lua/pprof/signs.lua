local M = {}

local config    = require("pprof.config")
local cache     = require("pprof.cache")
local util      = require("pprof.util")
local highlight = require("pprof.highlight")

local SIGN_GROUP  = "pprof"
local SIGN_PREFIX = "PprofHeat"

-- Separate namespaces so numhl/linehl clear independently of sign glyphs
local NS_NUM  = vim.api.nvim_create_namespace("pprof_numhl")
local NS_LINE = vim.api.nvim_create_namespace("pprof_linehl")

local _signs_defined = false
local _visible = {}  -- bufnr -> bool
local _lnums   = {}  -- bufnr -> integer[] sorted hot lnums (for navigation)

local function get_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function get_buf_filepath(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then return nil end
  return vim.fn.resolve(vim.fn.fnamemodify(name, ":p"))
end

local function ensure_signs_defined()
  if _signs_defined then return end
  local levels = (config.opts.signs and config.opts.signs.heat_levels) or 5
  highlight.setup(levels)
  for i = 1, levels do
    vim.fn.sign_define(SIGN_PREFIX .. i, {
      text   = "▎",
      texthl = SIGN_PREFIX .. i,
    })
  end
  _signs_defined = true
end

local function get_heat_levels()
  return (config.opts.signs and config.opts.signs.heat_levels) or 5
end

--- Deduplicate line annotations by lnum, keeping the entry with the highest flat value.
--- @param annotations RoutineAnnotation[]
--- @return table<integer, LineAnnotation>
local function dedup_lines(annotations)
  local seen = {}
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
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  local filepath = get_buf_filepath(bufnr)
  if not filepath then return end

  local annotations = cache.get_file(filepath)
  if not annotations or #annotations == 0 then return end

  local opts       = config.opts.signs or {}
  local levels     = get_heat_levels()
  local use_signhl = opts.signhl
  local use_numhl  = opts.numhl
  local use_linehl = opts.linehl
  local deduped    = dedup_lines(annotations)
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  -- Clear previous state
  vim.fn.sign_unplacelist({ { buffer = bufnr, group = SIGN_GROUP } })
  vim.api.nvim_buf_clear_namespace(bufnr, NS_NUM,  0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, NS_LINE, 0, -1)

  ensure_signs_defined()

  local place_list = {}
  local hot_lnums  = {}

  for lnum, line in pairs(deduped) do
    if line.flat == 0 and line.cum == 0 then goto continue end

    local level = util.heat_to_level(line.heat, levels)
    local row   = lnum - 1

    if use_signhl then
      place_list[#place_list + 1] = {
        buffer   = bufnr,
        group    = SIGN_GROUP,
        name     = SIGN_PREFIX .. level,
        lnum     = lnum,
        priority = opts.priority or 10,
      }
    end

    if use_numhl and row >= 0 and row < line_count then
      vim.api.nvim_buf_set_extmark(bufnr, NS_NUM, row, 0, {
        number_hl_group = SIGN_PREFIX .. "Number" .. level,
      })
    end

    if use_linehl and row >= 0 and row < line_count then
      vim.api.nvim_buf_set_extmark(bufnr, NS_LINE, row, 0, {
        line_hl_group = SIGN_PREFIX .. "Line" .. level,
      })
    end

    hot_lnums[#hot_lnums + 1] = lnum

    ::continue::
  end

  if #place_list > 0 then
    vim.fn.sign_placelist(place_list)
  end

  table.sort(hot_lnums)
  _lnums[bufnr]   = hot_lnums
  _visible[bufnr] = true
end

--- @param bufnr? integer
function M.hide(bufnr)
  bufnr = get_bufnr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  vim.fn.sign_unplacelist({ { buffer = bufnr, group = SIGN_GROUP } })
  vim.api.nvim_buf_clear_namespace(bufnr, NS_NUM,  0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, NS_LINE, 0, -1)
  _visible[bufnr] = false
  _lnums[bufnr]   = nil
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

--- @param bufnr? integer
function M.jump_next(bufnr)
  bufnr = get_bufnr(bufnr)
  local lnums = _lnums[bufnr]
  if not lnums or #lnums == 0 then return end
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  for _, lnum in ipairs(lnums) do
    if lnum > cur then
      vim.api.nvim_win_set_cursor(0, { lnum, 0 })
      return
    end
  end
  vim.api.nvim_win_set_cursor(0, { lnums[1], 0 })
end

--- @param bufnr? integer
function M.jump_prev(bufnr)
  bufnr = get_bufnr(bufnr)
  local lnums = _lnums[bufnr]
  if not lnums or #lnums == 0 then return end
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  for i = #lnums, 1, -1 do
    if lnums[i] < cur then
      vim.api.nvim_win_set_cursor(0, { lnums[i], 0 })
      return
    end
  end
  vim.api.nvim_win_set_cursor(0, { lnums[#lnums], 0 })
end

return M
