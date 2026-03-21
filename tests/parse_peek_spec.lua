local peek = require("pprof.parse.peek")

local function read_fixture(name)
  local path = vim.fn.getcwd() .. "/tests/fixtures/" .. name
  local f = io.open(path, "r")
  if not f then return "" end
  local content = f:read("*a")
  f:close()
  return content
end

describe("parse.peek.parse()", function()
  it("parses cpu profile peek output", function()
    local text = read_fixture("peek_cpu.txt")
    local result = peek.parse(text)

    assert.is_truthy(result.func_name)
    assert.is_truthy(result.func_name:find("matrixMultiply"))
    assert.is_truthy(result.self)
    assert.is_true(#result.callers > 0)
    assert.is_true(#result.callees > 0)
  end)

  it("self entry has correct value_str and pct", function()
    local text = read_fixture("peek_cpu.txt")
    local result = peek.parse(text)

    assert.is_truthy(result.self)
    assert.equals("0.79s", result.self.value_str)
    assert.equals(12.31, result.self.pct)
  end)

  it("identifies callers and callees", function()
    local text = read_fixture("peek_cpu.txt")
    local result = peek.parse(text)

    -- One caller: main.runComputeWorkloads
    assert.equals(1, #result.callers)
    assert.is_truthy(result.callers[1].name:find("runComputeWorkloads"))

    -- Two callees: runtime.asyncPreempt, runtime.makeslice
    assert.equals(2, #result.callees)
  end)

  it("returns empty PeekData for empty input", function()
    local result = peek.parse("")
    assert.equals("", result.func_name)
    assert.is_nil(result.self)
    assert.same({}, result.callees)
    assert.same({}, result.callers)
  end)

  it("returns empty PeekData for nil input", function()
    local result = peek.parse(nil)
    assert.equals("", result.func_name)
    assert.is_nil(result.self)
    assert.same({}, result.callees)
    assert.same({}, result.callers)
  end)
end)
