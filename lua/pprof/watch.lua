local M = {}

local config = require("pprof.config")

-- vim.uv is the preferred alias in Neovim 0.10+; fall back to vim.loop for 0.9
local uv = vim.uv or vim.loop

local fs_event       = nil
local debounce_timer = nil

--- @class WatchEvent
--- @field change? boolean
--- @field rename? boolean

--- @param path string
--- @param change_cb fun()
--- @param events? WatchEvent
local start

start = function(path, change_cb, events)
  if fs_event ~= nil then
    M.stop()
  end

  -- File may not yet exist (e.g. right after a rename); retry after debounce delay
  if vim.fn.filereadable(path) == 0 then
    local timeout_ms = (config.opts.auto_reload and config.opts.auto_reload.timeout_ms) or 500
    vim.defer_fn(function()
      start(path, change_cb, events or { rename = true })
    end, timeout_ms)
    return
  end

  -- Fire immediately if we were triggered by a rename (file replaced on disk)
  if events ~= nil and events.rename then
    change_cb()
  end

  fs_event = uv.new_fs_event()
  uv.fs_event_start(
    fs_event,
    path,
    { watch_entry = false, stat = false, recursive = false },
    function(err, _, ev)
      if err then
        vim.schedule(function()
          vim.notify("pprof: watch error: " .. err, vim.log.levels.ERROR)
        end)
        M.stop()
      elseif ev.rename then
        -- File was replaced; restart the watcher once it becomes readable again
        if debounce_timer ~= nil then
          uv.timer_stop(debounce_timer)
        end
        debounce_timer = vim.defer_fn(function()
          start(path, change_cb, ev)
        end, 0)
      else
        local timeout_ms = (config.opts.auto_reload and config.opts.auto_reload.timeout_ms) or 500
        if debounce_timer ~= nil then
          uv.timer_stop(debounce_timer)
        end
        debounce_timer = vim.defer_fn(function()
          debounce_timer = nil
          change_cb()
        end, timeout_ms)
      end
    end
  )
end

--- Start watching a file for changes, calling change_cb (debounced) on each change.
--- Handles rename events so atomic-replace writes (e.g. go test -cpuprofile) are caught.
--- @param path string
--- @param change_cb fun()
M.start = start

--- Stop the file watcher and cancel any pending debounce timer.
M.stop = function()
  if debounce_timer ~= nil then
    uv.timer_stop(debounce_timer)
    debounce_timer = nil
  end
  if fs_event ~= nil then
    uv.fs_event_stop(fs_event)
  end
  fs_event = nil
end

--- Check if actively watching a file.
--- @return boolean
M.is_watching = function()
  return fs_event ~= nil
end

return M
