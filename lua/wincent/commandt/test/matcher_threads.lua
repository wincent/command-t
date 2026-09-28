-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')
local c = require('wincent.commandt.private.lib.c')
local matcher_new = require('wincent.commandt.private.lib.matcher_new')
local matcher_run = require('wincent.commandt.private.lib.matcher_run')
local scanner_new_copy = require('wincent.commandt.private.lib.scanner_new_copy')

-- Compare one calling thread with pooled matchers on the same candidate order.
-- At least 1,000 candidates are needed to actually dispatch work to the pool.
-- Meaningful candidates are placed in different 64-candidate worker stripes;
-- the repeated filler only makes the input large enough to exercise threading.
describe('single-threaded versus pooled matchers', function()
  local scanners = {}
  local matchers = {}

  local function get_matcher(paths, options)
    local scanner = scanner_new_copy(paths)
    local matcher = matcher_new(scanner, options)
    scanners[#scanners + 1] = scanner
    matchers[#matchers + 1] = matcher
    return {
      match = function(query)
        local result = matcher_run(matcher, query)
        local matches = {}
        for i = 0, result.match_count - 1 do
          local candidate = result.matches[i]
          matches[#matches + 1] = ffi.string(candidate.contents, candidate.length)
        end
        c.commandt_result_free(ffi.gc(result, nil))
        return matches
      end,
    }
  end

  after(function()
    for _, matcher in ipairs(matchers) do
      c.commandt_matcher_free(ffi.gc(matcher, nil))
    end
    for _, scanner in ipairs(scanners) do
      c.commandt_scanner_free(ffi.gc(scanner, nil))
    end
    matchers = {}
    scanners = {}
  end)

  it('returns the same top three across two and four workers, including ties and the final partial stripe', function()
    local paths = {}
    for i = 1, 1025 do
      paths[i] = string.format('filler-%04d', i)
    end
    paths[1] = 'z.ab'
    paths[65] = 'y.ab'
    paths[129] = 'x.ab'
    paths[193] = 'w.ab'
    paths[257] = 'v.ab'
    paths[1025] = 'ab'

    local single = get_matcher(paths, { height = 3, threads = 1 })
    local two_workers = get_matcher(paths, { height = 3, threads = 2 })
    local four_workers = get_matcher(paths, { height = 3, threads = 4 })

    expect(single.match('ab')).to_equal({ 'ab', 'v.ab', 'w.ab' })
    expect(two_workers.match('ab')).to_equal({ 'ab', 'v.ab', 'w.ab' })
    expect(four_workers.match('ab')).to_equal({ 'ab', 'v.ab', 'w.ab' })
  end)

  it('agrees across query extensions, deletions, replacements, repeats, and case changes', function()
    local paths = {}
    for i = 1, 1025 do
      paths[i] = string.format('filler-%04d', i)
    end
    paths[1] = 'a'
    paths[65] = 'ab'
    paths[129] = 'aB'
    paths[193] = 'abc'
    paths[257] = 'Ab'
    paths[385] = 'AB'
    paths[577] = 'x/a'
    paths[1025] = 'a/b'

    local single = get_matcher(paths, { height = 3, threads = 1 })
    local pooled = get_matcher(paths, { height = 3, threads = 4 })

    expect(single.match('!')).to_equal({})
    expect(pooled.match('!')).to_equal({})
    expect(pooled.match('a')).to_equal(single.match('a'))
    expect(pooled.match('ab')).to_equal(single.match('ab'))
    expect(pooled.match('abc')).to_equal(single.match('abc'))
    expect(pooled.match('ab')).to_equal(single.match('ab'))
    expect(pooled.match('aB')).to_equal(single.match('aB'))
    expect(pooled.match('ab')).to_equal(single.match('ab'))
    expect(pooled.match('ab')).to_equal(single.match('ab'))
    expect(pooled.match('filler')).to_equal(single.match('filler'))
    expect(pooled.match('')).to_equal(single.match(''))
  end)

  it('selects the same alphabetical top three for a dot query across worker stripes', function()
    local paths = {}
    for i = 1, 1025 do
      paths[i] = string.format('filler-%04d', i)
    end
    paths[1] = 'z.'
    paths[65] = 'y.'
    paths[129] = 'x.'
    paths[193] = 'a.b'
    paths[257] = 'b.c'
    paths[321] = 'c.d'

    local single = get_matcher(paths, { height = 3, threads = 1 })
    local pooled = get_matcher(paths, { height = 3, threads = 4 })

    expect(single.match('.')).to_equal({ 'a.b', 'b.c', 'c.d' })
    expect(pooled.match('.')).to_equal({ 'a.b', 'b.c', 'c.d' })
  end)

  it('excludes hidden components consistently across worker stripes', function()
    local paths = {}
    for i = 1, 1025 do
      paths[i] = string.format('filler-%04d', i)
    end
    paths[1] = 'a.b/.hidden'
    paths[65] = 'a.b'
    paths[129] = 'x/.b'
    paths[193] = 'x.b'
    paths[1025] = '.ab'

    local single = get_matcher(paths, { height = 3, threads = 1, never_show_dot_files = true })
    local pooled = get_matcher(paths, { height = 3, threads = 4, never_show_dot_files = true })

    expect(single.match('.')).to_equal({ 'a.b', 'x.b' })
    expect(pooled.match('.')).to_equal({ 'a.b', 'x.b' })
    expect(single.match('.b')).to_equal({ 'a.b', 'x.b' })
    expect(pooled.match('.b')).to_equal({ 'a.b', 'x.b' })
  end)

  it('scores a long candidate on a background worker without overflowing its small stack', function()
    local paths = {}
    for i = 1, 1025 do
      paths[i] = string.format('filler-%04d', i)
    end
    local long_candidate = string.rep('x', 30000) .. 'ab'
    paths[65] = long_candidate -- Worker 1, not the calling thread's stripe.

    local single = get_matcher(paths, { height = 1, threads = 1 })
    local pooled = get_matcher(paths, { height = 1, threads = 4 })

    expect(single.match('ab')).to_equal({ long_candidate })
    expect(pooled.match('ab')).to_equal({ long_candidate })
  end)
end)
