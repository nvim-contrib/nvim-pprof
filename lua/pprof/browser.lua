local M = {}

local _job_id = nil
local _current_port = nil

--- Start the pprof HTTP server and open the browser.
--- @param profile_path string  absolute path to the profile file
--- @param port integer  HTTP port to listen on
function M.start(profile_path, port)
  if M.is_running() then
    vim.notify(
      "pprof: server already running at http://localhost:" .. _current_port,
      vim.log.levels.INFO
    )
    return
  end

  local stderr_lines = {}

  _job_id = vim.fn.jobstart({ "go", "tool", "pprof", "-http", ":" .. port, profile_path }, {
    on_stderr = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then
          stderr_lines[#stderr_lines + 1] = line
        end
      end
    end,
    on_exit = function(_, code)
      if _job_id ~= nil then
        -- Unexpected exit (not from M.stop())
        local msg = "pprof: server exited"
        if #stderr_lines > 0 then
          msg = msg .. ": " .. table.concat(stderr_lines, " ")
        end
        vim.notify(msg, vim.log.levels.WARN)
      end
      _job_id = nil
      _current_port = nil
    end,
  })

  if _job_id == nil or _job_id <= 0 then
    vim.notify("pprof: failed to start pprof server", vim.log.levels.ERROR)
    _job_id = nil
    return
  end

  _current_port = port

  vim.notify("pprof: server starting at http://localhost:" .. port, vim.log.levels.INFO)

  vim.defer_fn(function()
    if not M.is_running() then
      return
    end
    local opener = vim.fn.has("mac") == 1 and "open" or "xdg-open"
    vim.fn.jobstart({ opener, "http://localhost:" .. port })
  end, 800)
end

--- Stop the running pprof HTTP server.
function M.stop()
  if not M.is_running() then
    vim.notify("pprof: no server running", vim.log.levels.INFO)
    return
  end

  local port = _current_port
  -- Clear state before stopping so on_exit doesn't fire the "unexpected exit" warning
  local jid = _job_id
  _job_id = nil
  _current_port = nil

  vim.fn.jobstop(jid)
  vim.notify("pprof: server stopped (was http://localhost:" .. port .. ")", vim.log.levels.INFO)
end

--- Returns true if the pprof HTTP server job is currently running.
--- @return boolean
function M.is_running()
  return _job_id ~= nil and _job_id > 0
end

return M
