local util = require("pprof.util")

local function approx(expected, actual, tolerance)
  tolerance = tolerance or 1e-12
  return math.abs(expected - actual) < tolerance
end

describe("parse_value()", function()
  it("parses nanoseconds", function()
    assert.is_true(approx(120e-9, util.parse_value("120ns")))
  end)

  it("parses microseconds", function()
    assert.is_true(approx(500e-6, util.parse_value("500us")))
  end)

  it("parses milliseconds", function()
    assert.is_true(approx(0.120, util.parse_value("120ms")))
  end)

  it("parses seconds", function()
    assert.is_true(approx(1.20, util.parse_value("1.20s")))
  end)

  it("parses minutes", function()
    assert.is_true(approx(120, util.parse_value("2min")))
  end)

  it("parses bytes", function()
    assert.equals(100, util.parse_value("100B"))
  end)

  it("parses kilobytes", function()
    assert.equals(1024, util.parse_value("1kB"))
  end)

  it("parses megabytes", function()
    assert.equals(1048576, util.parse_value("1MB"))
  end)

  it("parses gigabytes", function()
    assert.equals(1073741824, util.parse_value("1GB"))
  end)

  it("returns 0 for dot", function()
    assert.equals(0, util.parse_value("."))
  end)

  it("returns 0 for empty string", function()
    assert.equals(0, util.parse_value(""))
  end)

  it("returns 0 for nil", function()
    assert.equals(0, util.parse_value(nil))
  end)

  it("parses dimensionless number", function()
    assert.equals(42, util.parse_value("42"))
  end)
end)

describe("heat_to_level()", function()
  it("maps heat=0.0 with 5 levels to 1", function()
    assert.equals(1, util.heat_to_level(0.0, 5))
  end)

  it("maps heat=1.0 with 5 levels to 5", function()
    assert.equals(5, util.heat_to_level(1.0, 5))
  end)

  it("maps heat=0.5 with 5 levels to 3", function()
    assert.equals(3, util.heat_to_level(0.5, 5))
  end)

  it("maps heat=0.0 with 1 level to 1", function()
    assert.equals(1, util.heat_to_level(0.0, 1))
  end)
end)

describe("lerp_color()", function()
  it("returns c1 at t=0", function()
    assert.equals("#3b82f6", util.lerp_color("#3b82f6", "#ef4444", 0))
  end)

  it("returns c2 at t=1", function()
    assert.equals("#ef4444", util.lerp_color("#3b82f6", "#ef4444", 1))
  end)
end)
