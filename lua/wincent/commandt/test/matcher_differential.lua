-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')
local c = require('wincent.commandt.private.lib.c')
local matcher_new = require('wincent.commandt.private.lib.matcher_new')
local matcher_run = require('wincent.commandt.private.lib.matcher_run')
local scanner_new_copy = require('wincent.commandt.private.lib.scanner_new_copy')

-- Seeds multiple matchers with the same candidates and compares them:
--
-- - Fresh versus reused: a query should return the same ordered results whether
--   it is the matcher's first query or follows earlier queries.
-- - Different result limits (`height`): a limited matcher should return the
--   corresponding prefix of a matcher that returns all results without pruning.
describe('matcher differential tests', function()
  local matchers = {}
  local scanners = {}
  local buffers = {}

  -- This adapter only manages C resources and converts results to Lua strings.
  -- Candidates, options, query history, and assertions belong in each test.
  local function get_matcher(paths, options)
    options = options or {}
    options.threads = 1
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
    -- Also runs when an assertion fails. Free matchers before their scanners.
    for _, matcher in ipairs(matchers) do
      c.commandt_matcher_free(ffi.gc(matcher, nil))
    end
    for _, scanner in ipairs(scanners) do
      c.commandt_scanner_free(ffi.gc(scanner, nil))
    end
    matchers = {}
    scanners = {}
    buffers = {}
  end)

  it('selects "a.b", not the higher-scoring "z.", when a dot query has only one result slot', function()
    local paths = { 'a.b', 'z.' }
    local two_results = get_matcher(paths, { height = 2 })
    local one_result = get_matcher(paths, { height = 1 })

    -- A lone dot requests alphabetical ordering, so reducing the limit should
    -- retain "a.b", even though the shorter "z." would have a higher score.
    expect(two_results.match('.')).to_equal({ 'a.b', 'z.' })
    expect(one_result.match('.')).to_equal({ 'a.b' })
  end)

  it('selects the alphabetical top three for a dot query even when shorter matches arrive first', function()
    local paths = { 'z.', 'y.', 'x.', 'a.b', 'b.c', 'c.d', 'no_dot' }
    local unpruned = get_matcher(paths, { height = #paths })
    local limited = get_matcher(paths, { height = 3 })

    -- Exercise replacement and reordering inside a multi-entry heap, not just
    -- the one-result case. "no_dot" must still be excluded as a non-match.
    expect(unpruned.match('.')).to_equal({ 'a.b', 'b.c', 'c.d', 'x.', 'y.', 'z.' })
    expect(limited.match('.')).to_equal({ 'a.b', 'b.c', 'c.d' })
  end)

  it('reconsiders an unselected dot match when the query is extended', function()
    local paths = { 'a.b', 'z.c' }
    local fresh = get_matcher(paths, { height = 1 })
    local reused = get_matcher(paths, { height = 1 })

    expect(reused.match('.')).to_equal({ 'a.b' })
    expect(fresh.match('.c')).to_equal({ 'z.c' })
    expect(reused.match('.c')).to_equal({ 'z.c' })
  end)

  it('agrees on cold and warmed dot queries, including nested hidden components and empty strings', function()
    local paths = { 'plain', 'z.', 'a.b', '.root', 'a/.one/.two/x', 'a.b/.tail', '' }
    local fresh = get_matcher(paths, { height = 7 })
    local warmed = get_matcher(paths, { height = 7 })

    expect(warmed.match('')).to_equal({ '', 'a.b', 'plain', 'z.' })
    expect(fresh.match('.')).to_equal({ '.root', 'a.b', 'a.b/.tail', 'a/.one/.two/x', 'z.' })
    expect(warmed.match('.')).to_equal({ '.root', 'a.b', 'a.b/.tail', 'a/.one/.two/x', 'z.' })
    expect(warmed.match('.')).to_equal({ '.root', 'a.b', 'a.b/.tail', 'a/.one/.two/x', 'z.' })
  end)

  it('agrees on cold and warmed dot queries when hidden components are always allowed', function()
    local paths = { 'plain', '.root', 'a/.one/.two/x', 'b.c', '' }
    local fresh = get_matcher(paths, { height = 5, always_show_dot_files = true })
    local warmed = get_matcher(paths, { height = 5, always_show_dot_files = true })

    expect(warmed.match('')).to_equal({ '', '.root', 'a/.one/.two/x', 'b.c', 'plain' })
    expect(fresh.match('.')).to_equal({ '.root', 'a/.one/.two/x', 'b.c' })
    expect(warmed.match('.')).to_equal({ '.root', 'a/.one/.two/x', 'b.c' })
    expect(warmed.match('.')).to_equal({ '.root', 'a/.one/.two/x', 'b.c' })
  end)

  it('keeps never_show_dot_files filtering after warming and repeating a dot query', function()
    local paths = { '.root', 'a.b/.tail', 'a/.one/.two/x', 'plain', 'z.', 'a.b', '' }
    local fresh = get_matcher(paths, { height = 7, never_show_dot_files = true })
    local warmed = get_matcher(paths, { height = 7, never_show_dot_files = true })

    expect(warmed.match('')).to_equal({ '', 'a.b', 'plain', 'z.' })
    expect(fresh.match('.')).to_equal({ 'a.b', 'z.' })
    expect(warmed.match('.')).to_equal({ 'a.b', 'z.' })
    expect(warmed.match('.')).to_equal({ 'a.b', 'z.' })
    expect(warmed.match('.tail')).to_equal({})
  end)

  it('reconsiders unselected matches and cached non-matches after a warmed dot query', function()
    local paths = { 'a.b', 'z.c', 'plain', '.root' }
    local fresh = get_matcher(paths, { height = 1 })
    local warmed = get_matcher(paths, { height = 1 })

    expect(warmed.match('')).to_equal({ 'a.b' })
    expect(warmed.match('.')).to_equal({ '.root' })
    expect(warmed.match('.')).to_equal({ '.root' })
    expect(fresh.match('.c')).to_equal({ 'z.c' })
    expect(warmed.match('.c')).to_equal({ 'z.c' })
    expect(warmed.match('.')).to_equal({ '.root' })
    expect(warmed.match('plain')).to_equal({ 'plain' })
    expect(warmed.match('')).to_equal({ 'a.b' })
  end)

  it('handles a dot query after a failed query initialized masks without scanning hidden dots', function()
    local paths = { 'plain', 'a.b/.c', 'a/.b/.c/z', 'a.c', '.root' }
    local fresh = get_matcher(paths, { height = 5 })
    local reused = get_matcher(paths, { height = 5 })

    expect(reused.match('!')).to_equal({})
    expect(reused.match('.')).to_equal({ '.root', 'a.b/.c', 'a.c', 'a/.b/.c/z' })
    expect(fresh.match('.c')).to_equal({ 'a.c', 'a.b/.c', 'a/.b/.c/z' })
    expect(reused.match('.c')).to_equal({ 'a.c', 'a.b/.c', 'a/.b/.c/z' })
    expect(reused.match('.z')).to_equal({ 'a/.b/.c/z' })
  end)

  it('recognizes a normalized dot query when spaces are ignored', function()
    local paths = { 'a.b', 'plain', 'z.c', '.root' }
    local fresh = get_matcher(paths, { height = 4, ignore_spaces = true })
    local warmed = get_matcher(paths, { height = 4, ignore_spaces = true })

    expect(warmed.match('')).to_equal({ 'a.b', 'plain', 'z.c' })
    expect(fresh.match(' . ')).to_equal({ '.root', 'a.b', 'z.c' })
    expect(warmed.match(' . ')).to_equal({ '.root', 'a.b', 'z.c' })
    expect(warmed.match('. c')).to_equal({ 'z.c' })
  end)

  it('preserves smart-case changes after extending a warmed dot query', function()
    local paths = { 'a.c', 'a.C', 'plain', '.cache' }
    local fresh = get_matcher(paths, { height = 4, ignore_case = true, smart_case = true })
    local warmed = get_matcher(paths, { height = 4, ignore_case = true, smart_case = true })

    expect(warmed.match('')).to_equal({ 'a.C', 'a.c', 'plain' })
    expect(warmed.match('.')).to_equal({ '.cache', 'a.C', 'a.c' })
    expect(fresh.match('.C')).to_equal({ 'a.C' })
    expect(warmed.match('.C')).to_equal({ 'a.C' })
    expect(warmed.match('.c')).to_equal({ 'a.C', 'a.c', '.cache' })
  end)

  it('does not find a dot beyond the recorded candidate length', function()
    local storage = ffi.new('char[8]', 'plain.x')
    local candidates = ffi.new('str_t[1]')
    candidates[0].contents = storage
    candidates[0].length = 5
    candidates[0].capacity = -1
    -- The scanner borrows both allocations. Keep them alive until teardown.
    buffers[#buffers + 1] = { storage, candidates }
    local scanner = ffi.gc(c.commandt_scanner_new_str(candidates, 1), c.commandt_scanner_free)
    local matcher = matcher_new(scanner, { height = 1, threads = 1 })
    scanners[#scanners + 1] = scanner
    matchers[#matchers + 1] = matcher

    local warmup = matcher_run(matcher, '')
    expect(warmup.match_count).to_be(1)
    c.commandt_result_free(ffi.gc(warmup, nil))
    local result = matcher_run(matcher, '.')
    expect(result.match_count).to_be(0)
    c.commandt_result_free(ffi.gc(result, nil))
  end)

  it('agrees on a long candidate before and after warming a dot query', function()
    local long_candidate = string.rep('x', 8192) .. '.tail'
    local paths = { 'z.', 'a.b', long_candidate, 'plain' }
    local fresh = get_matcher(paths, { height = 2 })
    local warmed = get_matcher(paths, { height = 2 })

    expect(warmed.match('')).to_equal({ 'a.b', 'plain' })
    expect(fresh.match('.')).to_equal({ 'a.b', long_candidate })
    expect(warmed.match('.')).to_equal({ 'a.b', long_candidate })
    expect(warmed.match('.tail')).to_equal({ long_candidate })
  end)

  it('excludes "a.b/." for ".b" in both fresh and reused never_show_dot_files matchers', function()
    local paths = { 'a.b/.' }
    local fresh = get_matcher(paths, { height = 1, never_show_dot_files = true })
    local reused = get_matcher(paths, { height = 1, never_show_dot_files = true })

    -- never_show_dot_files excludes the entire candidate, even though ".b"
    -- finishes before the hidden component. Previously the fresh matcher
    -- accepted it, while the reused matcher skipped it because "." cached zero.
    expect(fresh.match('.b')).to_equal({})
    expect(reused.match('.')).to_equal({})
    expect(reused.match('.b')).to_equal({})
  end)

  it('never shows hidden components after the matched text, including named components', function()
    local paths = { 'src/.hidden/file', 'src/file', '.src/file', 'src/file/.hidden' }
    local fresh = get_matcher(paths, { height = #paths, never_show_dot_files = true })
    local reused = get_matcher(paths, { height = #paths, never_show_dot_files = true })

    -- The visible candidate is a control: this must not reject every candidate.
    expect(fresh.match('src')).to_equal({ 'src/file' })
    expect(reused.match('')).to_equal({ 'src/file' })
    expect(reused.match('src')).to_equal({ 'src/file' })
    expect(reused.match('src.')).to_equal({})
    expect(reused.match('src')).to_equal({ 'src/file' })
  end)

  -- A fresh matcher whose limit equals the candidate count cannot fill its heap
  -- before scoring the final candidate. That disables threshold pruning without
  -- needing a production test hook. Inputs here are also far below the work cap.
  -- These comparisons check pruning and caching, not scoring optimality: the
  -- limited and unlimited matchers still share the same production scorer.

  it('returns the first unpruned result when only one result is requested', function()
    local paths = { 'alphabet', 'amber', 'b/a', 'zebra', 'a', 'zzz' }
    local unpruned = get_matcher(paths, { height = #paths })
    local limited = get_matcher(paths, { height = 1 })

    local all_results = unpruned.match('a')
    expect(#all_results).to_be(5)
    expect(limited.match('a')).to_equal({ all_results[1] })
  end)

  it('returns the first three unpruned results when the best matches arrive late', function()
    local paths = { 'a/long/path/b', 'a___b', 'alphabet', 'axb', 'a/b', 'a_b', 'aB', 'abc', 'ab', 'zzz' }
    local unpruned = get_matcher(paths, { height = #paths })
    local limited = get_matcher(paths, { height = 3 })

    local all_results = unpruned.match('ab')
    expect(#all_results).to_be(9)
    expect(limited.match('ab')).to_equal({ all_results[1], all_results[2], all_results[3] })
  end)

  it('returns the first three unpruned results when early good matches permit pruning', function()
    local paths = { 'ab', 'abc', 'aB', 'a_b', 'a/b', 'axb', 'alphabet', 'a___b', 'a/long/path/b', 'zzz' }
    local unpruned = get_matcher(paths, { height = #paths })
    local limited = get_matcher(paths, { height = 3 })

    local all_results = unpruned.match('ab')
    expect(#all_results).to_be(9)
    expect(limited.match('ab')).to_equal({ all_results[1], all_results[2], all_results[3] })
  end)

  it('returns the first seven unpruned results when seven results are requested', function()
    local paths = { 'a/long/path/b', 'a___b', 'alphabet', 'axb', 'a/b', 'a_b', 'aB', 'abc', 'ab', 'zzz' }
    local unpruned = get_matcher(paths, { height = #paths })
    local limited = get_matcher(paths, { height = 7 })

    local all_results = unpruned.match('ab')
    expect(#all_results).to_be(9)
    expect(limited.match('ab')).to_equal({
      all_results[1],
      all_results[2],
      all_results[3],
      all_results[4],
      all_results[5],
      all_results[6],
      all_results[7],
    })
  end)

  it('keeps alphabetical ties when the alphabetically best candidates arrive first', function()
    -- Every candidate has the same length and matches "a" at the same position.
    local paths = { 'aa', 'ab', 'ac', 'ad', 'ae', 'af', 'ag', 'ah', 'ai' }
    local unpruned = get_matcher(paths, { height = #paths })
    local limited = get_matcher(paths, { height = 3 })

    expect(unpruned.match('a')).to_equal({ 'aa', 'ab', 'ac', 'ad', 'ae', 'af', 'ag', 'ah', 'ai' })
    expect(limited.match('a')).to_equal({ 'aa', 'ab', 'ac' })
  end)

  it('replaces equal-scoring heap entries when alphabetically better candidates arrive later', function()
    local paths = { 'ai', 'ah', 'ag', 'af', 'ae', 'ad', 'ac', 'ab', 'aa' }
    local unpruned = get_matcher(paths, { height = #paths })
    local limited = get_matcher(paths, { height = 3 })

    expect(unpruned.match('a')).to_equal({ 'aa', 'ab', 'ac', 'ad', 'ae', 'af', 'ag', 'ah', 'ai' })
    expect(limited.match('a')).to_equal({ 'aa', 'ab', 'ac' })
  end)

  it('keeps alphabetical ties when candidates arrive in mixed order', function()
    local paths = { 'ae', 'ab', 'ai', 'ac', 'ag', 'aa', 'ah', 'ad', 'af' }
    local unpruned = get_matcher(paths, { height = #paths })
    local limited = get_matcher(paths, { height = 3 })

    expect(unpruned.match('a')).to_equal({ 'aa', 'ab', 'ac', 'ad', 'ae', 'af', 'ag', 'ah', 'ai' })
    expect(limited.match('a')).to_equal({ 'aa', 'ab', 'ac' })
  end)

  it('returns the alphabetical top three for an empty query', function()
    local paths = { 'z', 'alphabet', 'beta', 'alpha', '.hidden', 'a' }
    local unpruned = get_matcher(paths, { height = #paths })
    local limited = get_matcher(paths, { height = 3 })

    expect(unpruned.match('')).to_equal({ 'a', 'alpha', 'alphabet', 'beta', 'z' })
    expect(limited.match('')).to_equal({ 'a', 'alpha', 'alphabet' })
  end)

  it('reconsiders a pruned candidate when a replacement query is subsequently extended', function()
    local paths = { 'a', 'ab', 'abc', 'a/b' }
    local reused = get_matcher(paths, { height = 1 })
    local fresh_ab = get_matcher(paths, { height = 1 })
    local fresh_abc = get_matcher(paths, { height = 1 })

    -- First cache non-matches. Then "a" fills the heap and can prune "ab" and
    -- "abc" without rescoring them. Their earlier zeros must not exclude them
    -- when the query is extended to "ab" and then "abc".
    expect(reused.match('z')).to_equal({})
    expect(reused.match('a')).to_equal({ 'a' })
    expect(reused.match('ab')).to_equal(fresh_ab.match('ab'))
    expect(reused.match('abc')).to_equal(fresh_abc.match('abc'))
  end)

  it('agrees with fresh matchers when characters are deleted from the query', function()
    local paths = { 'a', 'ab', 'abc', 'a/b' }
    local reused = get_matcher(paths, { height = 1 })
    local fresh_ab = get_matcher(paths, { height = 1 })
    local fresh_a = get_matcher(paths, { height = 1 })

    expect(reused.match('abc')).to_equal({ 'abc' })
    expect(reused.match('ab')).to_equal(fresh_ab.match('ab'))
    expect(reused.match('a')).to_equal(fresh_a.match('a'))
  end)

  it('agrees with fresh matchers when a query is replaced and then extended', function()
    local paths = { 'a', 'ab', 'b', 'bc', 'b/c' }
    local reused = get_matcher(paths, { height = 1 })
    local fresh_b = get_matcher(paths, { height = 1 })
    local fresh_bc = get_matcher(paths, { height = 1 })

    expect(reused.match('a')).to_equal({ 'a' })
    expect(reused.match('b')).to_equal(fresh_b.match('b'))
    expect(reused.match('bc')).to_equal(fresh_bc.match('bc'))
  end)

  it('agrees with a fresh matcher when the same query is repeated', function()
    local paths = { 'a/long/path/b', 'axb', 'a/b', 'abc', 'ab' }
    local reused = get_matcher(paths, { height = 3 })
    local fresh = get_matcher(paths, { height = 3 })
    local expected = fresh.match('ab')

    expect(reused.match('ab')).to_equal(expected)
    expect(reused.match('ab')).to_equal(expected)
    expect(reused.match('ab')).to_equal(expected)
  end)

  it('agrees with a fresh matcher when a query is cleared', function()
    local paths = { 'alpha', '.alpha', 'beta', 'a/.beta' }
    local reused = get_matcher(paths, { height = #paths })
    local fresh = get_matcher(paths, { height = #paths })

    expect(reused.match('alpha')).to_equal({ 'alpha' })
    expect(reused.match('')).to_equal(fresh.match(''))
  end)

  it('reconsiders hidden candidates after the empty query excluded them', function()
    local paths = { '.ab', 'ab', 'a/.b' }
    local reused = get_matcher(paths, { height = #paths })
    local fresh = get_matcher(paths, { height = #paths })

    expect(reused.match('')).to_equal({ 'ab' })
    expect(fresh.match('.a')).to_equal({ '.ab' })
    expect(reused.match('.a')).to_equal({ '.ab' })
  end)

  it('agrees with a fresh matcher when smart case changes from sensitive to insensitive', function()
    local paths = { 'ab', 'aB', 'Ab', 'AB' }
    local reused = get_matcher(paths, { height = #paths })
    local fresh = get_matcher(paths, { height = #paths })

    expect(reused.match('aB')).to_equal({ 'aB' })
    expect(fresh.match('ab')).to_equal({ 'AB', 'Ab', 'aB', 'ab' })
    expect(reused.match('ab')).to_equal({ 'AB', 'Ab', 'aB', 'ab' })
  end)

  it('agrees with a fresh matcher when smart case changes from insensitive to sensitive', function()
    local paths = { 'ab', 'aB', 'Ab', 'AB' }
    local reused = get_matcher(paths, { height = #paths })
    local fresh = get_matcher(paths, { height = #paths })

    expect(reused.match('ab')).to_equal({ 'AB', 'Ab', 'aB', 'ab' })
    expect(fresh.match('aB')).to_equal({ 'aB' })
    expect(reused.match('aB')).to_equal({ 'aB' })
  end)

  it('agrees with a fresh matcher across case changes when smart case is disabled', function()
    local paths = { 'ab', 'aB', 'Ab', 'AB' }
    local reused = get_matcher(paths, { height = #paths, ignore_case = true, smart_case = false })
    local fresh = get_matcher(paths, { height = #paths, ignore_case = true, smart_case = false })

    expect(reused.match('A')).to_equal({ 'AB', 'Ab', 'aB', 'ab' })
    expect(fresh.match('aB')).to_equal({ 'AB', 'Ab', 'aB', 'ab' })
    expect(reused.match('aB')).to_equal({ 'AB', 'Ab', 'aB', 'ab' })
  end)

  it('agrees with a fresh matcher across case changes in case-sensitive mode', function()
    local paths = { 'ab', 'aB', 'Ab', 'AB' }
    local reused = get_matcher(paths, { height = #paths, ignore_case = false, smart_case = false })
    local fresh = get_matcher(paths, { height = #paths, ignore_case = false, smart_case = false })

    expect(reused.match('a')).to_equal({ 'aB', 'ab' })
    expect(fresh.match('A')).to_equal({ 'AB', 'Ab' })
    expect(reused.match('A')).to_equal({ 'AB', 'Ab' })
  end)

  it('agrees with a fresh matcher when smart_case is true but ignore_case is false', function()
    local paths = { 'ab', 'aB', 'Ab', 'AB' }
    local reused = get_matcher(paths, { height = #paths, ignore_case = false, smart_case = true })
    local fresh = get_matcher(paths, { height = #paths, ignore_case = false, smart_case = true })

    expect(reused.match('aB')).to_equal({ 'aB' })
    expect(fresh.match('ab')).to_equal({ 'ab' })
    expect(reused.match('ab')).to_equal({ 'ab' })
  end)

  it('agrees with fresh matchers when ignored spaces are added and removed', function()
    local paths = { 'ab', 'a b', 'a/b', 'a_b' }
    local reused = get_matcher(paths, { height = 2 })
    local fresh_with_space = get_matcher(paths, { height = 2 })
    local fresh_without_space = get_matcher(paths, { height = 2 })
    local fresh_a = get_matcher(paths, { height = 2 })

    reused.match('a')
    expect(reused.match('a b')).to_equal(fresh_with_space.match('a b'))
    expect(reused.match('ab')).to_equal(fresh_without_space.match('ab'))
    expect(reused.match('a ')).to_equal(fresh_a.match('a '))
  end)

  it('agrees with fresh matchers when spaces are literal query characters', function()
    local paths = { 'ab', 'a b', 'a  b', 'a/b', 'a_b' }
    local reused = get_matcher(paths, { height = 2, ignore_spaces = false })
    local fresh_with_space = get_matcher(paths, { height = 2, ignore_spaces = false })
    local fresh_without_space = get_matcher(paths, { height = 2, ignore_spaces = false })

    reused.match('ab')
    expect(reused.match('a b')).to_equal(fresh_with_space.match('a b'))
    expect(reused.match('ab')).to_equal(fresh_without_space.match('ab'))
  end)

  it('agrees with a fresh matcher when extending a query across nested hidden components', function()
    local paths = { '.b', '.bc', '.b/.c', 'a/.b', 'a/.b/.c', 'abc' }
    local reused = get_matcher(paths, { height = 3 })
    local fresh = get_matcher(paths, { height = 3 })

    reused.match('.b')
    expect(fresh.match('.b.c')).to_equal({ '.b/.c', 'a/.b/.c' })
    expect(reused.match('.b.c')).to_equal({ '.b/.c', 'a/.b/.c' })
  end)

  it('agrees with a fresh matcher when extending a dot query with always_show_dot_files', function()
    local paths = { 'a.b/.', 'a/.b', '.ab', 'ab' }
    local reused = get_matcher(paths, { height = 3, always_show_dot_files = true })
    local fresh = get_matcher(paths, { height = 3, always_show_dot_files = true })

    reused.match('.')
    expect(reused.match('.b')).to_equal(fresh.match('.b'))
  end)

  it('agrees with a fresh matcher while excluding leading hidden components with never_show_dot_files', function()
    local paths = { '.ab', 'a/.b', 'ab', 'a.b', 'x.b' }
    local reused = get_matcher(paths, { height = 3, never_show_dot_files = true })
    local fresh = get_matcher(paths, { height = 3, never_show_dot_files = true })

    expect(reused.match('.')).to_equal({ 'a.b', 'x.b' })
    expect(fresh.match('.b')).to_equal({ 'a.b', 'x.b' })
    expect(reused.match('.b')).to_equal({ 'a.b', 'x.b' })
  end)
end)
