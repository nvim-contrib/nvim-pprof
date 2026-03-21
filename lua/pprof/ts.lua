local M = {}

--- Classify a treesitter node as a function identifier.
--- Returns the identifier text if confirmed as a function name/call, nil otherwise.
--- @param node userdata  treesitter node
--- @param bufnr integer
--- @return string|nil
local function classify_func_node(node, bufnr)
  local ntype = node:type()
  if ntype ~= "identifier" and ntype ~= "field_identifier" then return nil end

  local parent = node:parent()
  if not parent then return nil end
  local ptype = parent:type()

  -- Function or method definition name
  if ptype == "function_declaration" or ptype == "method_declaration" then
    return vim.treesitter.get_node_text(node, bufnr)
  end

  -- Direct call: foo()
  if ptype == "call_expression" then
    return vim.treesitter.get_node_text(node, bufnr)
  end

  -- Method call: obj.Foo() — only field_identifier qualifies.
  -- This prevents `pkg` in `pkg.Func()` from matching (pkg is an identifier,
  -- not a field_identifier, so it falls through here).
  if ptype == "selector_expression" and ntype == "field_identifier" then
    local gp = parent:parent()
    if gp and gp:type() == "call_expression" then
      return vim.treesitter.get_node_text(node, bufnr)
    end
  end

  return nil
end

--- Determine whether the cursor is on a function name or call using treesitter.
---
--- Return contract:
---   (name, true)  — treesitter confirmed cursor is on a function; name is the identifier text
---   (nil, false)  — treesitter confirmed cursor is NOT on a function (warn the user)
---   (cword, false) — treesitter parser unavailable; cword is <cword> fallback (silent)
---
--- @return string|nil, boolean
function M.func_at_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "go")
  if not ok or not parser then
    local cword = vim.fn.expand("<cword>")
    return (cword ~= "" and cword or nil), false
  end

  local trees = parser:parse()
  if not trees or #trees == 0 then
    local cword = vim.fn.expand("<cword>")
    return (cword ~= "" and cword or nil), false
  end

  local node = trees[1]:root():named_descendant_for_range(row, col, row, col)
  if not node then return nil, false end

  local name = classify_func_node(node, bufnr)
  return name, name ~= nil
end

return M
