local config = require("pprof.config")

describe("config.setup()", function()
  before_each(function()
    -- Reset config to defaults before each test
    package.loaded["pprof.config"] = nil
    config = require("pprof.config")
  end)

  it("applies defaults when called with no args", function()
    config.setup()
    assert.equals("go", config.opts.pprof_bin)
    assert.equals(5, config.opts.signs.heat_levels)
    assert.equals(10, config.opts.signs.priority)
    assert.is_false(config.opts.signs.signhl)
    assert.is_true(config.opts.signs.numhl)
    assert.is_false(config.opts.signs.linehl)
    assert.is_false(config.opts.hints.enabled)
    assert.equals(20, config.opts.top.default_count)
  end)

  it("merges user options over defaults", function()
    config.setup({ pprof_bin = "/usr/bin/pprof" })
    assert.equals("/usr/bin/pprof", config.opts.pprof_bin)
    -- Other defaults still intact
    assert.equals(5, config.opts.signs.heat_levels)
  end)

  it("deep merges preserving sibling keys", function()
    config.setup({ signs = { heat_levels = 10 } })
    assert.equals(10, config.opts.signs.heat_levels)
    -- Sibling keys preserved
    assert.equals(10, config.opts.signs.priority)
    assert.is_true(config.opts.signs.numhl)
    assert.is_false(config.opts.signs.linehl)
  end)

  it("clamps heat_levels < 1 to 1", function()
    config.setup({ signs = { heat_levels = 0 } })
    assert.equals(1, config.opts.signs.heat_levels)
  end)
end)
