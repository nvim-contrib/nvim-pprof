local M = {}

local config = require("pprof.config")

local _watcher = nil
local _timer = nil

--- Start watching a file for changes, calling callback (debounced) on each change.
--- @param path string
--- @param callback fun()
function M.start(path, callback)
  M.stop()

  local debounce_ms = (config.opts.watch and config.opts.watch.debounce_ms) or 500

  local timer = vim.uv.new_timer()
  local watcher = vim.uv.new_fs_event()

  if not watcher or not timer then
    if timer and not timer:is_closing() then timer:close() end
    if watcher and not watcher:is_closing() then watcher:close() end
    vim.schedule(function()
      vim.notify("pprof: failed to create file watcher", vim.log.levels.ERROR)
    end)
    return
  end

  _timer = timer
  _watcher = watcher

  watcher:start(path, {}, function(err)
    if err then
      return
    end
    -- Restart debounce timer on each change event
    timer:stop()
    timer:start(debounce_ms, 0, function()
      timer:stop()
      vim.schedule(callback)
    end)
  end)
end

--- Stop the file watcher and cancel any pending debounce timer.
--- Timer must be cancelled before stopping the watcher.
function M.stop()
  -- Cancel pending debounce timer first (critical ordering)
  if _timer then
    _timer:stop()
    if not _timer:is_closing() then
      _timer:close()
    end
    _timer = nil
  end

  if _watcher then
    if not _watcher:is_closing() then
      _watcher:stop()
      _watcher:close()
    end
    _watcher = nil
  end
end

--- Check if actively watching a file.
--- @return boolean
function M.is_watching()
  return _watcher ~= nil
end

return M
