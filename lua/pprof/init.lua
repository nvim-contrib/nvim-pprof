local M = {}

local config    = require("pprof.config")
local cache     = require("pprof.cache")
local pprof     = require("pprof.pprof")
local parse     = require("pprof.parse")
local signs     = require("pprof.signs")
local hints     = require("pprof.hints")
local top_win   = require("pprof.top")
local peek_win  = require("pprof.peek")
local loclist   = require("pprof.loclist")
local highlight = require("pprof.highlight")
local watch     = require("pprof.watch")

local _autocmd_registered = false

--- Apply signs and hints to all currently loaded buffers that have cached annotations.
local function apply_to_open_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      if filepath ~= "" then
        -- Normalize to absolute path and resolve symlinks to match cache keys
        filepath = vim.fn.resolve(vim.fn.fnamemodify(filepath, ":p"))
        if cache.get_file(filepath) then
          if config.opts.signs and config.opts.signs.enabled then
            signs.show(bufnr)
          end
          if config.opts.hints and config.opts.hints.enabled then
            hints.show(bufnr)
          end
        end
      end
    end
  end
end

--- Perform the actual async load of a profile file.
--- @param path string  absolute path to .prof file
local function do_load(path)
  local list_stdout = nil
  local top_stdout  = nil
  local list_err    = nil
  local top_err     = nil
  local pending = 2

  local function on_both_done()
    pending = pending - 1
    if pending > 0 then return end

    if list_err then
      vim.notify("pprof: " .. list_err, vim.log.levels.ERROR)
      return
    end

    if top_err then
      vim.notify("pprof: top: " .. top_err, vim.log.levels.WARN)
    end

    local parsed_list = parse.list.parse(list_stdout or "")
    local parsed_top  = parse.top.parse(top_stdout or "")

    -- Normalize file paths in the cache list by resolving symlinks
    -- This ensures consistency when matching buffer paths
    local normalized_list = {}
    for filepath, annotations in pairs(parsed_list.list or {}) do
      local resolved = vim.fn.resolve(filepath)
      normalized_list[resolved] = annotations
    end

    -- cache.set MUST happen before on_load callback
    cache.set({
      profile_path = path,
      list         = normalized_list,
      top          = parsed_top,
      total_str    = parsed_list.total_str,
    })

    apply_to_open_buffers()

    if config.opts.watch and config.opts.watch.enabled then
      watch.start(path, function()
        do_load(path)
      end)
    end

    if config.opts.on_load then
      vim.schedule(function()
        config.opts.on_load()
      end)
    end
  end

  pprof.run_list(path, function(err, stdout)
    list_err    = err
    list_stdout = stdout
    on_both_done()
  end)

  pprof.run_top(path, config.opts.top.default_count, function(err, stdout)
    top_err    = err
    top_stdout = stdout
    on_both_done()
  end)
end

--- Register the BufReadPost autocmd for auto-applying signs/hints.
local function register_autocmds()
  if _autocmd_registered then return end
  _autocmd_registered = true

  vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("pprof_bufread", { clear = true }),
    callback = function(ev)
      if not cache.is_loaded() then return end
      local filepath = vim.api.nvim_buf_get_name(ev.buf)
      if filepath == "" then return end
      -- Normalize to absolute path and resolve symlinks to match cache keys
      filepath = vim.fn.resolve(vim.fn.fnamemodify(filepath, ":p"))
      if not cache.get_file(filepath) then return end
      if config.opts.signs and config.opts.signs.enabled then
        signs.show(ev.buf)
      end
      if config.opts.hints and config.opts.hints.enabled then
        hints.show(ev.buf)
      end
    end,
  })
end

--- Register all user-facing commands.
local function register_commands()
  local function def(name, fn, opts)
    pcall(vim.api.nvim_del_user_command, name)
    vim.api.nvim_create_user_command(name, fn, opts or {})
  end

  def("PProfTest", function()
    -- Test manual sign/hint display
    local data = cache.get()
    if not data then
      vim.notify("pprof: no profile loaded", vim.log.levels.WARN)
      return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    vim.notify("Attempting to show signs on buffer " .. bufnr, vim.log.levels.INFO)
    signs.show(bufnr)
    vim.notify("Attempting to show hints on buffer " .. bufnr, vim.log.levels.INFO)
    hints.show(bufnr)
  end, {})

  def("PProfDebug", function()
    local data = cache.get()
    if not data then
      vim.notify("pprof: no profile loaded", vim.log.levels.WARN)
      return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    local buf_name = vim.api.nvim_buf_get_name(bufnr)
    local abs_path = vim.fn.fnamemodify(buf_name, ":p")
    local cwd = vim.fn.getcwd()

    local msg = "=== PProfDebug ===\n"
    msg = msg .. "Working directory: " .. cwd .. "\n"
    msg = msg .. "Buffer name: " .. buf_name .. "\n"
    msg = msg .. "Absolute path: " .. abs_path .. "\n"
    msg = msg .. "Profile path: " .. (data.profile_path or "?") .. "\n"
    msg = msg .. "\nCache keys:\n"

    local found = false
    local count = 0
    for filepath, annotations in pairs(data.list or {}) do
      count = count + 1
      local match = filepath == abs_path
      msg = msg .. (match and "✓ " or "  ") .. filepath .. " (" .. #annotations .. " routines)\n"
      if match then
        found = true
      end
    end

    msg = msg .. "\nTotal files in cache: " .. count
    if not found then
      msg = msg .. "\n\n✗ NO MATCH in cache"
    else
      msg = msg .. "\n\n✓ MATCH FOUND"
    end

    vim.notify(msg, vim.log.levels.INFO)
  end, {})

  def("PProfLoad", function(a)
    local path = a.args ~= "" and a.args or nil
    M.load(path, a.bang)
  end, { nargs = "?", bang = true, complete = "file" })

  def("PProfSigns", function(a)
    M.signs(a.args ~= "" and a.args or "toggle")
  end, { nargs = "?" })

  def("PProfHints", function(a)
    M.hints(a.args ~= "" and a.args or "toggle")
  end, { nargs = "?" })

  def("PProfTop", function(a)
    local count = a.args ~= "" and tonumber(a.args) or nil
    M.top(count)
  end, { nargs = "?" })

  def("PProfPeek", function(a)
    M.peek(a.args ~= "" and a.args or nil)
  end, { nargs = "?" })

  def("PProfNext", function() M.next() end, {})
  def("PProfPrev", function() M.prev() end, {})
  def("PProfLoclist", function() M.loclist() end, {})
  def("PProfClear", function() M.clear() end, {})
end

--- Configure nvim-pprof. Call this once during setup.
--- @param opts table|nil
function M.setup(opts)
  config.setup(opts)
  highlight.setup(config.opts.signs and config.opts.signs.heat_levels or 5)
  register_commands()
  register_autocmds()
end

--- Load a pprof profile file.
--- @param path string|nil  path to .prof file; if nil, searches cwd
--- @param use_picker boolean|nil  if true, always show vim.ui.select for multiple files
function M.load(path, use_picker)
  if path and path ~= "" then
    do_load(vim.fn.expand(path))
    return
  end

  local prof_files = vim.fn.glob(vim.fn.getcwd() .. "/*.prof", false, true)

  if #prof_files == 0 then
    vim.notify("pprof: no .prof files found in current directory", vim.log.levels.WARN)
    return
  end

  if #prof_files == 1 and not use_picker then
    do_load(prof_files[1])
    return
  end

  -- Multiple files or bang: show picker
  vim.ui.select(prof_files, { prompt = "Select profile:" }, function(choice)
    if choice then
      do_load(choice)
    end
  end)
end

--- Show, hide, or toggle signs for the current buffer.
--- @param action string  "show"|"hide"|"toggle"
function M.signs(action)
  if action == "show" then
    signs.show()
  elseif action == "hide" then
    signs.hide()
  else
    signs.toggle()
  end
end

--- Show, hide, or toggle inline hints for the current buffer.
--- @param action string  "show"|"hide"|"toggle"
function M.hints(action)
  if action == "show" then
    hints.show()
  elseif action == "hide" then
    hints.hide()
  else
    hints.toggle()
  end
end

--- Show top entries from the loaded profile in a floating window.
--- @param count integer|nil  number of entries (defaults to config)
function M.top(count)
  local data = cache.get()
  if not data then
    vim.notify("pprof: no profile loaded", vim.log.levels.WARN)
    return
  end

  local entries = data.top or {}
  if count and count < #entries then
    entries = vim.list_slice(entries, 1, count)
  end

  top_win.show(entries, data.total_str or "")
end

--- Show peek (callers/callees) for a function in a floating window.
--- @param func_name string|nil  function name; if nil, uses word under cursor
function M.peek(func_name)
  local data = cache.get()
  if not data then
    vim.notify("pprof: no profile loaded", vim.log.levels.WARN)
    return
  end

  if not func_name or func_name == "" then
    func_name = vim.fn.expand("<cword>")
  end

  if not func_name or func_name == "" then
    vim.notify("pprof: no function name", vim.log.levels.WARN)
    return
  end

  pprof.run_peek(data.profile_path, func_name, function(err, stdout)
    if err then
      vim.notify("pprof: peek error: " .. err, vim.log.levels.ERROR)
      return
    end
    local peek_data = parse.peek.parse(stdout)
    peek_win.show(peek_data)
  end)
end

--- Jump to the next annotated line in the current buffer.
function M.next()
  signs.jump_next()
end

--- Jump to the previous annotated line in the current buffer.
function M.prev()
  signs.jump_prev()
end

--- Populate the location list with profile hotspot lines.
function M.loclist()
  loclist.populate()
end

--- Clear all profile data: cache, signs, hints, floats, watcher.
function M.clear()
  watch.stop()
  top_win.close()
  peek_win.close()

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      signs.hide(bufnr)
      hints.hide(bufnr)
    end
  end

  cache.clear()
end

return M
