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
local quickfix  = require("pprof.quickfix")
local highlight = require("pprof.highlight")
local watch     = require("pprof.watch")
local ts        = require("pprof.ts")

local _autocmd_registered = false

--- Returns true if any sign channel (glyph, numhl, linehl) is configured on.
local function signs_active()
  local s = config.opts.signs
  return s and (s.signhl or s.numhl or s.linehl)
end

--- Apply signs and hints to all currently loaded buffers that have cached annotations.
local function apply_to_open_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      if filepath ~= "" then
        -- Normalize to absolute path and resolve symlinks to match cache keys
        filepath = vim.fn.resolve(vim.fn.fnamemodify(filepath, ":p"))
        if cache.get_file(filepath) then
          if signs_active() then
            signs.show(bufnr)
          end
          if config.opts.line_hints and config.opts.line_hints.enabled then
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

    if config.opts.auto_reload and config.opts.auto_reload.enabled then
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
      if signs_active() then
        signs.show(ev.buf)
      end
      if config.opts.line_hints and config.opts.line_hints.enabled then
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

  def("PProfLoad", function(a)
    local path = a.args ~= "" and a.args or nil
    M.load(path, a.bang)
  end, { nargs = "?", bang = true, complete = "file" })

  local function action_complete()
    return { "show", "hide", "toggle" }
  end

  local function action_cmd(actions)
    return function(a)
      local action = a.args ~= "" and a.args or "toggle"
      local fn = actions[action]
      if fn then
        fn()
      else
        vim.notify("Invalid action: " .. action, vim.log.levels.ERROR)
      end
    end
  end

  def("PProfSigns", action_cmd({
    show = M.show_signs,
    hide = M.hide_signs,
    toggle = M.toggle_signs,
  }), { nargs = "?", complete = action_complete })

  def("PProfHints", action_cmd({
    show = M.show_hints,
    hide = M.hide_hints,
    toggle = M.toggle_hints,
  }), { nargs = "?", complete = action_complete })

  def("PProfTop", function(a)
    local count = a.args ~= "" and tonumber(a.args) or nil
    M.top(count)
  end, { nargs = "?" })

  def("PProfPeek", function(a)
    M.peek(a.args ~= "" and a.args or nil)
  end, { nargs = "?" })

  def("PProfQuickfix", function() M.quickfix() end, {})
  def("PProfLoclist", function() M.loclist() end, {})
  def("PProfClear", function() M.clear() end, {})
end

--- Configure nvim-pprof. Call this once during setup.
--- @param opts table|nil
function M.setup(opts)
  config.setup(opts)
  highlight.setup(config.opts.signs and config.opts.signs.heat_levels or 5)
  if config.opts.commands then
    register_commands()
  end
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

--- Re-render signs on all buffers that currently have signs visible.
local function reapply_signs()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and signs.is_visible(bufnr) then
      signs.show(bufnr)
    end
  end
end

--- Show heat-gradient signs for the current buffer.
function M.show_signs()
  signs.show()
end

--- Hide heat-gradient signs for the current buffer.
function M.hide_signs()
  signs.hide()
end

--- Toggle heat-gradient signs for the current buffer.
function M.toggle_signs()
  signs.toggle()
end

--- Enable the sign column glyph and re-render.
function M.show_signhl()
  config.opts.signs.signhl = true
  reapply_signs()
end

--- Disable the sign column glyph and re-render.
function M.hide_signhl()
  config.opts.signs.signhl = false
  reapply_signs()
end

--- Toggle the sign column glyph and re-render.
function M.toggle_signhl()
  config.opts.signs.signhl = not config.opts.signs.signhl
  reapply_signs()
end

--- Enable line number coloring and re-render.
function M.show_numhl()
  config.opts.signs.numhl = true
  reapply_signs()
end

--- Disable line number coloring and re-render.
function M.hide_numhl()
  config.opts.signs.numhl = false
  reapply_signs()
end

--- Toggle line number coloring and re-render.
function M.toggle_numhl()
  config.opts.signs.numhl = not config.opts.signs.numhl
  reapply_signs()
end

--- Enable full-line background coloring and re-render.
function M.show_linehl()
  config.opts.signs.linehl = true
  reapply_signs()
end

--- Disable full-line background coloring and re-render.
function M.hide_linehl()
  config.opts.signs.linehl = false
  reapply_signs()
end

--- Toggle full-line background coloring and re-render.
function M.toggle_linehl()
  config.opts.signs.linehl = not config.opts.signs.linehl
  reapply_signs()
end

--- Show inline hints for the current buffer.
function M.show_hints()
  hints.show()
end

--- Hide inline hints for the current buffer.
function M.hide_hints()
  hints.hide()
end

--- Toggle inline hints for the current buffer.
function M.toggle_hints()
  hints.toggle()
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
--- @param func_name string|nil  function name; if nil, uses treesitter to detect function under cursor
function M.peek(func_name)
  local data = cache.get()
  if not data then
    vim.notify("pprof: no profile loaded", vim.log.levels.WARN)
    return
  end

  if not func_name or func_name == "" then
    local ts_name = ts.func_at_cursor()
    if ts_name then
      func_name = ts_name
    else
      -- treesitter confirmed: cursor is not on a function
      vim.notify("pprof: cursor is not on a function name or call", vim.log.levels.WARN)
      return
    end
  end

  pprof.run_peek(data.profile_path, func_name, function(err, stdout)
    if err then
      vim.notify("pprof: peek error: " .. err, vim.log.levels.ERROR)
      return
    end
    peek_win.show(parse.peek.parse(stdout))
  end)
end


--- Populate the quickfix list with one entry per profiled file.
function M.quickfix()
  quickfix.populate()
end

--- Populate the location list with profile hotspot lines.
function M.loclist()
  loclist.populate()
end

--- Jump to the next hotspot sign in the current buffer.
function M.jump_next()
  signs.jump(1)
end

--- Jump to the previous hotspot sign in the current buffer.
function M.jump_prev()
  signs.jump(-1)
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
