local M = {}

local config = require("pprof.config")
local cache = require("pprof.cache")
local util = require("pprof.util")
local highlight = require("pprof.highlight")

local SIGN_GROUP = "pprof"
local SIGN_PREFIX = "PprofHeat"

local _signs_defined = false
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

local function ensure_signs_defined()
  if _signs_defined then
    return
  end
  local opts = config.opts
  local levels = opts.signs and opts.signs.heat_levels or 5
  highlight.setup(levels)
  for i = 1, levels do
    vim.fn.sign_define(SIGN_PREFIX .. i, {
      text = "▌",
      texthl = SIGN_PREFIX .. i,
      numhl = "",
    })
  end
  _signs_defined = true
end

local function get_heat_levels()
  local opts = config.opts
  return (opts.signs and opts.signs.heat_levels) or 5
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

  ensure_signs_defined()
  local levels = get_heat_levels()

  local deduped = dedup_lines(annotations)

  -- Build sign placement list
  local place_list = {}
  for lnum, line in pairs(deduped) do
    -- Skip lines with no profiling data
    if line.flat == 0 and line.cum == 0 then
      goto continue
    end

    local level = util.heat_to_level(line.heat, levels)
    place_list[#place_list + 1] = {
      buffer = bufnr,
      group = SIGN_GROUP,
      name = SIGN_PREFIX .. level,
      lnum = lnum,
      priority = 10,
    }

    ::continue::
  end

  if #place_list == 0 then
    return
  end

  -- Remove existing signs first to avoid duplicates
  vim.fn.sign_unplacelist({ { buffer = bufnr, group = SIGN_GROUP } })

  vim.fn.sign_placelist(place_list)
  _visible[bufnr] = true
end

--- @param bufnr? integer
function M.hide(bufnr)
  bufnr = get_bufnr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  vim.fn.sign_unplacelist({ { buffer = bufnr, group = SIGN_GROUP } })
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

--- Collect all signed lnums in sorted order for the buffer.
--- @param bufnr integer
--- @return integer[]
local function get_signed_lnums(bufnr)
  local placed = vim.fn.sign_getplaced(bufnr, { group = SIGN_GROUP })
  if not placed or #placed == 0 then
    return {}
  end
  local signs = placed[1].signs
  if not signs or #signs == 0 then
    return {}
  end

  local lnum_set = {}
  for _, sign in ipairs(signs) do
    lnum_set[sign.lnum] = true
  end

  local lnums = {}
  for lnum in pairs(lnum_set) do
    lnums[#lnums + 1] = lnum
  end
  table.sort(lnums)
  return lnums
end

--- @param bufnr? integer
function M.jump_next(bufnr)
  bufnr = get_bufnr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local lnums = get_signed_lnums(bufnr)
  if #lnums == 0 then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_lnum = cursor[1]

  -- Find first lnum strictly after cursor
  local target = nil
  for _, lnum in ipairs(lnums) do
    if lnum > cur_lnum then
      target = lnum
      break
    end
  end

  -- Wrap around to first
  if not target then
    target = lnums[1]
  end

  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

--- @param bufnr? integer
function M.jump_prev(bufnr)
  bufnr = get_bufnr(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local lnums = get_signed_lnums(bufnr)
  if #lnums == 0 then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_lnum = cursor[1]

  -- Find last lnum strictly before cursor
  local target = nil
  for i = #lnums, 1, -1 do
    if lnums[i] < cur_lnum then
      target = lnums[i]
      break
    end
  end

  -- Wrap around to last
  if not target then
    target = lnums[#lnums]
  end

  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

return M
