local M = {}

local cache = require("pprof.cache")
local ts    = require("pprof.ts")

local client_id = nil

-- Lazy-require the main module to avoid a circular dependency at load time.
local function pprof()
  return require("pprof")
end

local COMMANDS = {
  ["pprof.peek"] = function(args) pprof().peek(args and args[1]) end,
}

local function build_code_actions()
  if not cache.get() then return {} end

  local ts_name, ts_confirmed = ts.func_at_cursor()
  local actions = {}

  if ts_name then
    local title = ts_confirmed
      and string.format("pprof: Peek %s", ts_name)
      or  string.format("pprof: Peek (cword fallback) %s", ts_name)
    -- No kind: peek is cursor-context dependent, so it belongs in the regular
    -- code_action menu only — not in source-filtered actions (<Leader>lA).
    actions[#actions + 1] = {
      title   = title,
      command = { title = title, command = "pprof.peek", arguments = { ts_name } },
    }
  end

  return actions
end

--- Create the in-process RPC transport.
--- Neovim calls this with a dispatchers table; we return a PublicClient.
--- rpc.request must return (true, id: number) — Neovim 0.11 validates the id.
local function create_rpc(dispatchers)
  local closed  = false
  local next_id = 0

  local function new_id()
    next_id = next_id + 1
    return next_id
  end

  return {
    request = function(method, params, callback)
      if method == "initialize" then
        callback(nil, {
          capabilities = {
            codeActionProvider     = true,
            executeCommandProvider = { commands = vim.tbl_keys(COMMANDS) },
          },
        })
        return true, new_id()

      elseif method == "textDocument/codeAction" then
        -- Use vim.schedule so the callback fires asynchronously, which is
        -- required when buf_request_all aggregates responses from multiple
        -- clients (calling the callback synchronously inside request() would
        -- decrement the pending counter before all clients have been queued).
        local id = new_id()
        vim.schedule(function()
          callback(nil, build_code_actions())
        end)
        return true, id

      elseif method == "workspace/executeCommand" then
        local fn = COMMANDS[params.command]
        local id = new_id()
        vim.schedule(function()
          if fn then fn(params.arguments) end
          callback(nil, nil)
        end)
        return true, id

      elseif method == "shutdown" then
        callback(nil, nil)
        return true, new_id()
      end

      return false, nil
    end,

    notify = function(_method, _params)
      return true
    end,

    is_closing = function()
      return closed
    end,

    terminate = function()
      closed = true
      dispatchers.on_exit(0, 0)
    end,
  }
end

--- Start the virtual LSP client and attach it to Go buffers.
--- Requires Neovim 0.9+ (cmd-as-function support in vim.lsp.start_client).
function M.setup()
  local ok, id = pcall(vim.lsp.start_client, {
    name = "pprof",
    cmd  = create_rpc,
  })

  if not ok or not id then
    -- Silently degrade on older Neovim builds that don't support function cmd.
    return
  end

  client_id = id

  local group = vim.api.nvim_create_augroup("pprof_lsp", { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group   = group,
    pattern = "go",
    callback = function(ev)
      vim.lsp.buf_attach_client(ev.buf, client_id)
    end,
  })

  -- Attach to Go buffers that are already open.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == "go" then
      vim.lsp.buf_attach_client(bufnr, client_id)
    end
  end
end

return M
