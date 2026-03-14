local config = require("pprof.config")

local M = {}

--- Build the base command for invoking pprof.
--- @param args string[]  additional arguments before profile_path
--- @param profile_path string
--- @return string[]
local function build_cmd(args, profile_path)
  local bin = config.opts.pprof_bin or "go"
  local cmd

  if bin == "go" then
    cmd = { "go", "tool", "pprof" }
  else
    cmd = { bin }
  end

  for _, a in ipairs(args) do
    cmd[#cmd + 1] = a
  end

  cmd[#cmd + 1] = profile_path
  return cmd
end

--- Run a pprof command asynchronously.
--- @param cmd string[]
--- @param callback fun(err: string|nil, stdout: string)
local function run_async(cmd, callback)
  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local err = result.stderr or ("pprof exited with code " .. result.code)
        callback(err, "")
      else
        callback(nil, result.stdout or "")
      end
    end)
  end)
end

--- Run `pprof -list .` and return stdout via callback.
--- @param profile_path string
--- @param callback fun(err: string|nil, stdout: string)
function M.run_list(profile_path, callback)
  local cmd = build_cmd({ "-list", "." }, profile_path)
  run_async(cmd, callback)
end

--- Run `pprof -top -nodecount=N` and return stdout via callback.
--- @param profile_path string
--- @param count integer
--- @param callback fun(err: string|nil, stdout: string)
function M.run_top(profile_path, count, callback)
  local nodecount = string.format("-nodecount=%d", count or config.opts.top.default_count)
  local cmd = build_cmd({ "-top", nodecount }, profile_path)
  run_async(cmd, callback)
end

--- Run `pprof -peek func_name` and return stdout via callback.
--- @param profile_path string
--- @param func_name string
--- @param callback fun(err: string|nil, stdout: string)
function M.run_peek(profile_path, func_name, callback)
  local cmd = build_cmd({ "-peek", func_name }, profile_path)
  run_async(cmd, callback)
end

return M
