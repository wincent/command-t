-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

-- Exercises the asynchronous exec scanner (`scanner_new_exec_async`) and the
-- matcher's streaming path (candidate count growing between runs) against the
-- real C library, the same way `test/matcher.lua` does.
--
-- Determinism without relying on timing:
--   - Tier 1 waits for `commandt_scanner_done()` before asserting, so results
--     are compared only against the complete candidate set.
--   - Tier 2 drives production through a FIFO and polls `scanner.count` until it
--     reaches a known value before asserting, so the producer can never race
--     ahead of what the test has fed it.

local ffi = require('ffi')

describe('scanner_new_exec_async', function()
  local c = require('wincent.commandt.private.lib.c')
  local matcher_new = require('wincent.commandt.private.lib.matcher_new')
  local matcher_run = require('wincent.commandt.private.lib.matcher_run')
  local scanner_new_copy = require('wincent.commandt.private.lib.scanner_new_copy')
  local scanner_new_exec_async = require('wincent.commandt.private.lib.scanner_new_exec_async')

  -- Hold references to every scanner/matcher for the duration of the run so the
  -- garbage collector can't free a scanner while a matcher still points at it.
  local keep_alive = {}
  local function retain(value)
    keep_alive[#keep_alive + 1] = value
    return value
  end

  local function wait_until(predicate, description)
    local waited = 0
    while not predicate() do
      os.execute('sleep 0.005')
      waited = waited + 5
      if waited > 5000 then
        error(description .. ' (timed out after 5s)')
      end
    end
  end

  local function wait_until_done(scanner)
    wait_until(function()
      return c.commandt_scanner_done(scanner)
    end, 'scanner did not finish')
  end

  local function now()
    local e = c.commandt_epoch()
    return tonumber(e.seconds) + tonumber(e.microseconds) / 1e6
  end

  local function match_all(matcher, query)
    local results = matcher_run(matcher, query)
    local out = {}
    for k = 0, results.match_count - 1 do
      local str = results.matches[k]
      table.insert(out, ffi.string(str.contents, str.length))
    end
    return out
  end

  -- Build a `printf` command that emits each path followed by a NUL.
  local function nul_command(paths)
    local args = {}
    for _, p in ipairs(paths) do
      args[#args + 1] = "'" .. p .. "'"
    end
    return "printf '%s\\0' " .. table.concat(args, ' ')
  end

  local function async_matcher(command, drop, max_files, options)
    local scanner = retain(scanner_new_exec_async(command, drop or 0, max_files or 0))
    wait_until_done(scanner)
    local matcher = retain(matcher_new(scanner, options or {}))
    return matcher, scanner
  end

  local function copy_matcher(paths, options)
    local scanner = retain(scanner_new_copy(paths))
    return retain(matcher_new(scanner, options or {}))
  end

  it('produces the same results as a synchronous scanner', function()
    local paths = { 'foo/bar', 'foo/baz', 'bing', 'foo/qux' }
    local async = async_matcher(nul_command(paths))
    local sync = copy_matcher(paths)
    for _, query in ipairs({ '', 'b', 'z', 'foo', 'q', 'xyz' }) do
      expect(match_all(async, query)).to_equal(match_all(sync, query))
    end
  end)

  it('handles a command that produces no output', function()
    local matcher, scanner = async_matcher('true')
    expect(tonumber(scanner.count)).to_be(0)
    expect(match_all(matcher, '')).to_equal({})
    expect(match_all(matcher, 'x')).to_equal({})
  end)

  it('honors max_files', function()
    local paths = {}
    for i = 1, 20 do
      paths[i] = 'file' .. i
    end
    local _, scanner = async_matcher(nul_command(paths), 0, 5)
    expect(tonumber(scanner.count)).to_be(5)
  end)

  it('drops the requested prefix', function()
    local matcher = async_matcher("printf '%s\\0' './foo' './bar'", 2, 0)
    expect(match_all(matcher, '')).to_equal({ 'bar', 'foo' })
  end)

  it('reports done, and can be stopped idempotently without losing results', function()
    local matcher, scanner = async_matcher(nul_command({ 'apple', 'banana' }))
    expect(not not c.commandt_scanner_done(scanner)).to_be(true)
    c.commandt_scanner_stop(scanner)
    c.commandt_scanner_stop(scanner) -- Idempotent.
    expect(not not c.commandt_scanner_done(scanner)).to_be(true)
    -- Matching reads the slab, not the pipe, so it still works after stop.
    -- ("apple" outscores "banana" for "a": its match is at the start.)
    expect(match_all(matcher, 'a')).to_equal({ 'apple', 'banana' })
  end)

  it('stops promptly even while the command is still firehosing output', function()
    -- A pipeline (so `/bin/sh` forks children) that streams forever. This guards
    -- the teardown regression: stop() must signal the whole process group, not
    -- just the shell, or the orphaned producer keeps the pipe open and stop()
    -- blocks. A full regression hangs here (bounded only by the CI job timeout);
    -- a partial slowdown is caught by the timing assertion below.
    local command = "yes /a/reasonably/long/path/component/file.txt | tr '\\n' '\\0' 2>/dev/null"
    local scanner = retain(scanner_new_exec_async(command, 0, 0))
    os.execute('sleep 0.2') -- Let it stream.

    -- Stop first, so even if an assertion below fails the firehose is gone.
    local produced = tonumber(scanner.count)
    local start = now()
    c.commandt_scanner_stop(scanner)
    local elapsed = now() - start

    expect(produced > 0).to_be(true)
    expect(elapsed < 1).to_be(true)
    expect(not not c.commandt_scanner_done(scanner)).to_be(true)
  end)

  context('when waiting for completion', function()
    it('drains delayed and split tokens before returning, and tolerates repeated cleanup', function()
      local scanner = retain(scanner_new_exec_async("printf './al'; sleep 0.02; printf 'pha\\0./beta\\0'", 2, 0))
      c.commandt_scanner_wait(scanner)
      expect(not not c.commandt_scanner_done(scanner)).to_be(true)
      expect(tonumber(scanner.count)).to_be(2)

      c.commandt_scanner_wait(scanner)
      c.commandt_scanner_stop(scanner)
      c.commandt_scanner_wait(scanner)
      local matcher = retain(matcher_new(scanner, {}))
      expect(match_all(matcher, '')).to_equal({ 'alpha', 'beta' })
    end)

    it('handles an empty command result', function()
      local scanner = retain(scanner_new_exec_async('true', 0, 0))
      c.commandt_scanner_wait(scanner)
      expect(not not c.commandt_scanner_done(scanner)).to_be(true)
      expect(tonumber(scanner.count)).to_be(0)
    end)

    it('finishes at max_files even if the command would otherwise run forever', function()
      local scanner = retain(scanner_new_exec_async("while :; do printf './alpha\\0'; done", 2, 3))
      c.commandt_scanner_wait(scanner)
      expect(not not c.commandt_scanner_done(scanner)).to_be(true)
      expect(tonumber(scanner.count)).to_be(3)
      local matcher = retain(matcher_new(scanner, {}))
      expect(match_all(matcher, '')).to_equal({ 'alpha', 'alpha', 'alpha' })
    end)

    it('cleans up the command after stdout closes, without waiting for its remaining work', function()
      local scanner = retain(scanner_new_exec_async("printf 'alpha\\0'; exec 1>&-; sleep 5", 0, 0))
      local start = now()
      c.commandt_scanner_wait(scanner)
      local elapsed = now() - start
      expect(elapsed < 2).to_be(true)
      expect(not not c.commandt_scanner_done(scanner)).to_be(true)
      local matcher = retain(matcher_new(scanner, {}))
      expect(match_all(matcher, '')).to_equal({ 'alpha' })
    end)

    it('is a no-op for eager scanners', function()
      for _, paths in ipairs({ {}, { 'alpha' } }) do
        local scanner = retain(scanner_new_copy(paths))
        c.commandt_scanner_wait(scanner)
        c.commandt_scanner_wait(scanner)
        local matcher = retain(matcher_new(scanner, {}))
        expect(match_all(matcher, '')).to_equal(paths)
      end
    end)

    it('lets the benchmark adapter return a complete async scan', function()
      local exec = require('wincent.commandt.private.scanners.exec')
      local scanner = retain(exec.scanner("sleep 0.02; printf './alpha\\0./beta\\0'", 2, 1))
      expect(not not c.commandt_scanner_done(scanner)).to_be(true)
      expect(tonumber(scanner.count)).to_be(1)
      local matcher = retain(matcher_new(scanner, {}))
      expect(match_all(matcher, '')).to_equal({ 'alpha' })
    end)

    it('keeps the blocking constructor available as a compatibility wrapper', function()
      local scanner_new_exec = require('wincent.commandt.private.lib.scanner_new_exec')
      local scanner = retain(scanner_new_exec("printf './alpha\\0./beta\\0'", 2, 1))
      expect(not not c.commandt_scanner_done(scanner)).to_be(true)
      expect(tonumber(scanner.count)).to_be(1)
      local matcher = retain(matcher_new(scanner, {}))
      expect(match_all(matcher, '')).to_equal({ 'alpha' })
    end)
  end)

  context('while streaming (candidate count growing between runs)', function()
    it('matches like a synchronous scanner at each stage of production', function()
      local fifo = os.tmpname()
      os.remove(fifo) -- `tmpname` creates the file; remove so `mkfifo` can create it.
      local status = os.execute('mkfifo ' .. fifo)
      if status ~= 0 and status ~= true then
        error('mkfifo failed')
      end

      -- The scanner reads `cat`'s stdout; we feed `cat` through the FIFO.
      local scanner = retain(scanner_new_exec_async('cat ' .. fifo, 0, 0))
      -- Open O_RDWR ('r+') so the open never blocks and we hold a write end.
      local writer = assert(io.open(fifo, 'r+'))
      local matcher = retain(matcher_new(scanner, {}))

      local produced = {}
      local function feed(tokens)
        for _, token in ipairs(tokens) do
          writer:write(token)
          writer:write('\0')
          produced[#produced + 1] = token
        end
        writer:flush()
        local target = #produced
        wait_until(function()
          return tonumber(scanner.count) >= target
        end, 'count did not reach ' .. target)
      end

      local function expect_matches_synchronous(queries)
        for _, query in ipairs(queries) do
          local sync = copy_matcher(produced)
          expect(match_all(matcher, query)).to_equal(match_all(sync, query))
        end
      end

      feed({ 'alpha', 'beta', 'gamma' })
      expect(tonumber(scanner.count)).to_be(3)
      expect_matches_synchronous({ '', 'a', 'e', 'x' })

      feed({ 'delta', 'alef', 'echo' })
      expect(tonumber(scanner.count)).to_be(6)
      expect_matches_synchronous({ '', 'a', 'e', 'l', 'x' })

      writer:close() -- EOF: `cat` exits and the producer finishes.
      wait_until_done(scanner)
      expect_matches_synchronous({ '', 'a', 'e', 'l', 'd', 'x' })

      os.remove(fifo)
    end)
  end)
end)
