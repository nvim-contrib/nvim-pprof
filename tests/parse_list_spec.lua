local list = require("pprof.parse.list")

local function read_fixture(name)
  local path = vim.fn.getcwd() .. "/tests/fixtures/" .. name
  local f = io.open(path, "r")
  if not f then return "" end
  local content = f:read("*a")
  f:close()
  return content
end

describe("parse.list.parse()", function()
  it("parses cpu profile list output", function()
    local text = read_fixture("list_cpu.txt")
    local result = list.parse(text)

    assert.equals("6.42s", result.total_str)
    assert.is_true(vim.tbl_count(result.list) > 0)

    -- Check that compute.go file key exists
    local compute_key = nil
    for k, _ in pairs(result.list) do
      if k:find("compute.go") then
        compute_key = k
        break
      end
    end
    assert.is_truthy(compute_key)

    -- compute.go should have multiple routines
    local routines = result.list[compute_key]
    assert.is_true(#routines > 0)
  end)

  it("lines have correct lnum, flat_str, cum_str values", function()
    local text = read_fixture("list_cpu.txt")
    local result = list.parse(text)

    -- Find the matrixMultiply routine in compute.go
    local routine = nil
    for _, routines in pairs(result.list) do
      for _, r in ipairs(routines) do
        if r.func_name == "main.matrixMultiply" then
          routine = r
          break
        end
      end
      if routine then break end
    end

    assert.is_truthy(routine)
    assert.is_true(#routine.lines > 0)

    -- Line 16 (c[i][j] += a[i][k] * b[k][j]) should have flat=790ms
    local hot_line = nil
    for _, ln in ipairs(routine.lines) do
      if ln.lnum == 16 then
        hot_line = ln
        break
      end
    end
    assert.is_truthy(hot_line)
    assert.equals("790ms", hot_line.flat_str)
    assert.equals("850ms", hot_line.cum_str)
  end)

  it("normalizes heat: hottest line approaches 1.0, zero lines have heat 0.0", function()
    local text = read_fixture("list_cpu.txt")
    local result = list.parse(text)

    -- Find the matrixMultiply routine
    local routine = nil
    for _, routines in pairs(result.list) do
      for _, r in ipairs(routines) do
        if r.func_name == "main.matrixMultiply" then
          routine = r
          break
        end
      end
      if routine then break end
    end

    assert.is_truthy(routine)

    local max_heat = 0
    local has_zero_heat = false
    for _, ln in ipairs(routine.lines) do
      if ln.heat > max_heat then max_heat = ln.heat end
      if ln.flat == 0 then
        assert.equals(0, ln.heat)
        has_zero_heat = true
      end
    end

    -- Hottest line should have heat = 1.0
    assert.equals(1.0, max_heat)
    -- Should have some zero-heat lines
    assert.is_true(has_zero_heat)
  end)

  it("returns empty result for empty input", function()
    local result = list.parse("")
    assert.same({}, result.list)
    assert.equals("", result.total_str)
  end)
end)
