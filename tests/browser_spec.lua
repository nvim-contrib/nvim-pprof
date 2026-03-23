local browser

describe("browser state machine", function()
  local orig_jobstart
  local orig_jobstop
  local orig_defer_fn
  local orig_notify
  local notify_calls

  before_each(function()
    package.loaded["pprof.browser"] = nil
    browser = require("pprof.browser")

    notify_calls = {}
    orig_notify = vim.notify
    vim.notify = function(msg, level)
      notify_calls[#notify_calls + 1] = { msg = msg, level = level }
    end

    orig_jobstart = vim.fn.jobstart
    vim.fn.jobstart = function(_, _)
      return 42
    end

    orig_jobstop = vim.fn.jobstop
    vim.fn.jobstop = function(_) end

    orig_defer_fn = vim.defer_fn
    vim.defer_fn = function(_, _) end
  end)

  after_each(function()
    vim.notify = orig_notify
    vim.fn.jobstart = orig_jobstart
    vim.fn.jobstop = orig_jobstop
    vim.defer_fn = orig_defer_fn
  end)

  it("is not running initially", function()
    assert.is_false(browser.is_running())
  end)

  it("is running after start()", function()
    browser.start("/tmp/cpu.prof", 8080)
    assert.is_true(browser.is_running())
  end)

  it("notifies the URL on start()", function()
    browser.start("/tmp/cpu.prof", 9090)
    assert.equals(1, #notify_calls)
    assert.truthy(notify_calls[1].msg:find("9090", 1, true))
  end)

  it("does not call jobstart a second time when already running", function()
    local call_count = 0
    vim.fn.jobstart = function(_, _)
      call_count = call_count + 1
      return 42
    end

    browser.start("/tmp/cpu.prof", 8080)
    browser.start("/tmp/cpu.prof", 8080)

    assert.equals(1, call_count)
  end)

  it("notifies 'already running' when start() is called twice", function()
    browser.start("/tmp/cpu.prof", 8080)
    notify_calls = {}
    browser.start("/tmp/cpu.prof", 8080)
    assert.equals(1, #notify_calls)
    assert.truthy(notify_calls[1].msg:find("already running", 1, true))
  end)

  it("is not running after stop()", function()
    browser.start("/tmp/cpu.prof", 8080)
    browser.stop()
    assert.is_false(browser.is_running())
  end)

  it("calls jobstop with the correct job id on stop()", function()
    local stopped_jid = nil
    vim.fn.jobstop = function(jid)
      stopped_jid = jid
    end

    browser.start("/tmp/cpu.prof", 8080)
    browser.stop()
    assert.equals(42, stopped_jid)
  end)

  it("notifies when stopped", function()
    browser.start("/tmp/cpu.prof", 8080)
    notify_calls = {}
    browser.stop()
    assert.equals(1, #notify_calls)
    assert.truthy(notify_calls[1].msg:find("stopped", 1, true))
  end)

  it("notifies 'no server running' when stop() called without a server", function()
    browser.stop()
    assert.equals(1, #notify_calls)
    assert.truthy(notify_calls[1].msg:find("no server running", 1, true))
  end)

  it("can be restarted after stop()", function()
    local call_count = 0
    vim.fn.jobstart = function(_, _)
      call_count = call_count + 1
      return call_count * 10
    end

    browser.start("/tmp/cpu.prof", 8080)
    browser.stop()
    browser.start("/tmp/cpu.prof", 8080)
    assert.equals(2, call_count)
    assert.is_true(browser.is_running())
  end)
end)
