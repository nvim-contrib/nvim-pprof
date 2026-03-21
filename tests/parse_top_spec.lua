local top = require("pprof.parse.top")

local function read_fixture(name)
  local path = vim.fn.getcwd() .. "/tests/fixtures/" .. name
  local f = io.open(path, "r")
  if not f then return "" end
  local content = f:read("*a")
  f:close()
  return content
end

describe("parse.top.parse()", function()
  it("parses cpu profile top output", function()
    local text = read_fixture("top_cpu.txt")
    local entries = top.parse(text)

    assert.is_true(#entries > 0)

    -- First entry should be runtime.madvise (highest flat)
    local first = entries[1]
    assert.equals("2.56s", first.flat_str)
    assert.equals(39.88, first.flat_pct)
    assert.equals("runtime.madvise", first.func_name)

    -- Entries with "(inline)" suffix are not matched by the parser pattern,
    -- so the second parsed entry is runtime.kevent
    local second = entries[2]
    assert.equals("0.64s", second.flat_str)
    assert.equals(9.97, second.flat_pct)
    assert.equals("runtime.kevent", second.func_name)
  end)

  it("parses memory profile top output", function()
    local text = read_fixture("top_mem.txt")
    local entries = top.parse(text)

    assert.is_true(#entries > 0)

    local first = entries[1]
    assert.equals("1.27GB", first.flat_str)
    assert.equals(99.68, first.flat_pct)
    assert.equals("main.runAllocateWorkloads", first.func_name)
  end)

  it("returns empty table for empty input", function()
    local entries = top.parse("")
    assert.same({}, entries)
  end)

  it("returns empty table for nil input", function()
    local entries = top.parse(nil)
    assert.same({}, entries)
  end)
end)
