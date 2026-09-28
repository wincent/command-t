-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')
local reference_score = require('wincent.commandt.test.score_reference')

ffi.cdef([[
  float commandt_test_score(
    const char *candidate,
    const char *query,
    bool ignore_case,
    bool always_show_dot_files,
    bool never_show_dot_files
  );
  unsigned commandt_test_allocation_count(void);
]])

local directory = debug.getinfo(1).source:match('@?(.*/)') .. '../lib/.make/'
local extension = ffi.os == 'Windows' and '.dll' or '.so'
local default_library = ffi.load(directory .. 'score-default' .. extension)
local heap_library = ffi.load(directory .. 'score-heap' .. extension)
local capped_library = ffi.load(directory .. 'score-capped' .. extension)
local capped_heap_library = ffi.load(directory .. 'score-capped-heap' .. extension)
local late_cap_heap_library = ffi.load(directory .. 'score-late-cap-heap' .. extension)

local function score(library, candidate, query, options)
  options = options or {}
  if options.ignore_case then
    -- commandt_score receives an already-normalized needle from the matcher.
    query = query:gsub('[A-Z]', string.lower)
  end
  return library.commandt_test_score(
    candidate,
    query,
    options.ignore_case or false,
    options.always_show_dot_files or false,
    options.never_show_dot_files or false
  )
end

-- Compare the C scorer with an independent enumeration of every legal alignment.
-- The heap build lowers SCORE_SCRATCH_STACK to 2. The capped builds lower
-- SCORE_CELL_CAP to 0, so any attempt to score a DP cell enters the fallback.
-- Cells and interior-gap predecessor checks share the work budget. A separate
-- cap-4 heap build exercises fallback after partial DP work.
-- All calls disable threshold pruning. Float comparisons allow rounding error
-- because the Lua oracle uses doubles while the C scorer uses floats.
describe('score.c against an exhaustive alignment oracle', function()
  it('scores an empty query without dividing by zero', function()
    expect(reference_score('', '')).to_be(1)
    expect(score(default_library, '', '')).to_be(1)
    expect(score(heap_library, '', '')).to_be(1)
  end)

  it('rejects a non-empty query against an empty candidate', function()
    expect(reference_score('', 'a')).to_be(0)
    expect(score(default_library, '', 'a')).to_be(0)
    expect(score(heap_library, '', 'a')).to_be(0)
  end)

  it('requires a separate candidate character for each repeated query character', function()
    expect(reference_score('aba', 'aaa')).to_be(0)
    expect(score(default_library, 'aba', 'aaa')).to_be(0)
    expect(score(heap_library, 'aba', 'aaa')).to_be(0)
  end)

  it('gives either of the first two candidate positions the full initial factor', function()
    expect(reference_score('ax', 'a')).to_be(0.75)
    expect(reference_score('xa', 'a')).to_be(0.75)
    expect(score(default_library, 'ax', 'a')).to_be(0.75)
    expect(score(default_library, 'xa', 'a')).to_be(0.75)
  end)

  it('adds the constant consecutive bonus, allowing scores greater than one', function()
    -- base = 1/2; the first match contributes base and the second 1.3 * base.
    local expected = reference_score('ab', 'ab')
    expect(expected).to_be_close_to(1.15)
    expect(score(default_library, 'ab', 'ab')).to_be_close_to(expected)
    expect(score(heap_library, 'ab', 'ab')).to_be_close_to(expected)
  end)

  it('finds a better later alignment instead of committing to the first matching character', function()
    -- Taking "a" at the start is worse than matching the consecutive "ab"
    -- after the slash. The oracle tries both complete alignments.
    local expected = reference_score('a/ab', 'ab')
    expect(expected).to_be_close_to(0.825)
    expect(score(default_library, 'a/ab', 'ab')).to_be_close_to(expected)
    expect(score(heap_library, 'a/ab', 'ab')).to_be_close_to(expected)
  end)

  it('uses heap scratch for a short candidate when the stack limit is forced to two', function()
    local expected = reference_score('x/a', 'a')

    expect(score(default_library, 'x/a', 'a')).to_be_close_to(expected)
    expect(default_library.commandt_test_allocation_count()).to_be(0)
    expect(score(heap_library, 'x/a', 'a')).to_be_close_to(expected)
    expect(heap_library.commandt_test_allocation_count()).to_be(1)
  end)

  it('is exact at the normal 2,048-position stack scratch limit', function()
    local candidate = string.rep('x', 2046) .. 'ab'
    local expected = reference_score(candidate, 'ab')
    expect(score(default_library, candidate, 'ab')).to_be_close_to(expected)
    expect(default_library.commandt_test_allocation_count()).to_be(0)
    expect(score(heap_library, candidate, 'ab')).to_be_close_to(expected)
    expect(heap_library.commandt_test_allocation_count()).to_be(1)
  end)

  it('is exact just beyond the normal stack scratch limit', function()
    local candidate = string.rep('x', 2047) .. 'ab'
    local expected = reference_score(candidate, 'ab')
    expect(score(default_library, candidate, 'ab')).to_be_close_to(expected)
    expect(default_library.commandt_test_allocation_count()).to_be(1)
    expect(score(heap_library, candidate, 'ab')).to_be_close_to(expected)
    expect(heap_library.commandt_test_allocation_count()).to_be(1)
  end)

  it('scores a slash boundary', function()
    local expected = reference_score('x/a', 'a')
    expect(expected).to_be_close_to(0.6)
    expect(score(default_library, 'x/a', 'a')).to_be_close_to(expected)
    expect(score(heap_library, 'x/a', 'a')).to_be_close_to(expected)
  end)

  it('scores an underscore boundary', function()
    local expected = reference_score('x_a', 'a')
    expect(expected).to_be_close_to(8 / 15)
    expect(score(default_library, 'x_a', 'a')).to_be_close_to(expected)
    expect(score(heap_library, 'x_a', 'a')).to_be_close_to(expected)
  end)

  it('scores a dash boundary', function()
    local expected = reference_score('x-a', 'a')
    expect(expected).to_be_close_to(8 / 15)
    expect(score(default_library, 'x-a', 'a')).to_be_close_to(expected)
    expect(score(heap_library, 'x-a', 'a')).to_be_close_to(expected)
  end)

  it('scores a space boundary', function()
    local expected = reference_score('x a', 'a')
    expect(expected).to_be_close_to(8 / 15)
    expect(score(default_library, 'x a', 'a')).to_be_close_to(expected)
    expect(score(heap_library, 'x a', 'a')).to_be_close_to(expected)
  end)

  it('scores a digit boundary', function()
    local expected = reference_score('x0a', 'a')
    expect(expected).to_be_close_to(8 / 15)
    expect(score(default_library, 'x0a', 'a')).to_be_close_to(expected)
    expect(score(heap_library, 'x0a', 'a')).to_be_close_to(expected)
  end)

  it('scores an ordinary dot boundary', function()
    local expected = reference_score('x.a', 'a')
    expect(expected).to_be_close_to(7 / 15)
    expect(score(default_library, 'x.a', 'a')).to_be_close_to(expected)
    expect(score(heap_library, 'x.a', 'a')).to_be_close_to(expected)
  end)

  it('keeps the camel-case boundary bonus when matching ignores case', function()
    local options = { ignore_case = true }
    local expected = reference_score('xxA', 'a', options)
    expect(expected).to_be_close_to(8 / 15)
    expect(score(default_library, 'xxA', 'a', options)).to_be_close_to(expected)
    expect(score(heap_library, 'xxA', 'a', options)).to_be_close_to(expected)
  end)

  it('does not fold case when case-sensitive matching is requested', function()
    expect(reference_score('xxA', 'a', { ignore_case = false })).to_be(0)
    expect(score(default_library, 'xxA', 'a', { ignore_case = false })).to_be(0)
    expect(score(heap_library, 'xxA', 'a', { ignore_case = false })).to_be(0)
  end)

  it('decays the score across a gap inside a word', function()
    local expected = reference_score('xxa', 'a')
    expect(expected).to_be_close_to(0.25)
    expect(score(default_library, 'xxa', 'a')).to_be_close_to(expected)
    expect(score(heap_library, 'xxa', 'a')).to_be_close_to(expected)
  end)

  it('does not cross a hidden component without an available query dot', function()
    expect(reference_score('a/.b', 'ab')).to_be(0)
    expect(score(default_library, 'a/.b', 'ab')).to_be(0)
    expect(score(heap_library, 'a/.b', 'ab')).to_be(0)
  end)

  it('can choose a hidden dot instead of an earlier ordinary dot', function()
    local expected = reference_score('a.b/.c', '.c')
    expect(expected > 0).to_be(true)
    expect(score(default_library, 'a.b/.c', '.c')).to_be_close_to(expected)
    expect(score(heap_library, 'a.b/.c', '.c')).to_be_close_to(expected)
  end)

  it('can search past multiple hidden components with one unconsumed query dot', function()
    local expected = reference_score('a/.b/.c/z', '.z')
    expect(expected > 0).to_be(true)
    expect(score(default_library, 'a/.b/.c/z', '.z')).to_be_close_to(expected)
    expect(score(heap_library, 'a/.b/.c/z', '.z')).to_be_close_to(expected)
  end)

  it('needs another query dot after matching intervening text', function()
    expect(reference_score('a/.b/x/.c/z', '.xz')).to_be(0)
    expect(score(default_library, 'a/.b/x/.c/z', '.xz')).to_be(0)
    expect(score(heap_library, 'a/.b/x/.c/z', '.xz')).to_be(0)

    local expected = reference_score('a/.b/x/.c/z', '.x.z')
    expect(expected > 0).to_be(true)
    expect(score(default_library, 'a/.b/x/.c/z', '.x.z')).to_be_close_to(expected)
    expect(score(heap_library, 'a/.b/x/.c/z', '.x.z')).to_be_close_to(expected)
  end)

  it('permits crossing hidden components when always_show_dot_files is true', function()
    local options = { always_show_dot_files = true }
    local expected = reference_score('a/.b', 'ab', options)
    expect(expected > 0).to_be(true)
    expect(score(default_library, 'a/.b', 'ab', options)).to_be_close_to(expected)
    expect(score(heap_library, 'a/.b', 'ab', options)).to_be_close_to(expected)
  end)

  it('rejects hidden components after the match when never_show_dot_files is true', function()
    local options = { never_show_dot_files = true }
    expect(reference_score('a.b/.c', '.b', options)).to_be(0)
    expect(score(default_library, 'a.b/.c', '.b', options)).to_be(0)
    expect(score(heap_library, 'a.b/.c', '.b', options)).to_be(0)
  end)

  it('preserves the empty-query exclusion sentinel for hidden candidates', function()
    expect(reference_score('a/.b', '')).to_be(-1)
    expect(score(default_library, 'a/.b', '')).to_be(-1)
    expect(score(heap_library, 'a/.b', '')).to_be(-1)
  end)
end)

describe('forced work-cap fallback', function()
  it('may under-rank a candidate but must return a positive lower bound, on stack and heap', function()
    local exact = reference_score('a/ab', 'ab')
    local capped = score(capped_library, 'a/ab', 'ab')
    local capped_heap = score(capped_heap_library, 'a/ab', 'ab')

    -- This also proves that the forced build really took the fallback: exact
    -- scoring chooses the later "ab", while greedy scoring takes the first "a".
    expect(exact).to_be_close_to(0.825)
    expect(capped).to_be_close_to(0.46875)
    expect(capped > 0 and capped < exact).to_be(true)
    expect(capped_heap).to_be_close_to(capped)
    expect(capped_library.commandt_test_allocation_count()).to_be(0)
    expect(capped_heap_library.commandt_test_allocation_count()).to_be(1)
  end)

  it('still scores exactly at the four-unit work cap instead of falling back immediately', function()
    local exact = reference_score('a/ab', 'ab')
    local immediate = score(capped_library, 'a/ab', 'ab')
    local delayed = score(late_cap_heap_library, 'a/ab', 'ab')

    -- Two a positions, one b position, and one predecessor check exactly fill
    -- the budget. Immediate greedy fallback takes the wrong a; this build must
    -- finish the exact alignment without treating the exhausted budget as exceeded.
    expect(immediate).to_be_close_to(0.46875)
    expect(delayed).to_be_close_to(exact)
    expect(delayed > immediate).to_be(true)
    expect(late_cap_heap_library.commandt_test_allocation_count()).to_be(1)
  end)

  it('counts ordinary predecessor checks even when matching cells fit below the cap', function()
    local exact = reference_score('aaxb', 'ab')
    local capped = score(late_cap_heap_library, 'aaxb', 'ab')

    -- Only three cells match: two a's and one b. Checking the a at index 1
    -- fills the four-unit budget; checking the a at index 0 must trigger the
    -- fallback, even though that check would have stopped the predecessor loop.
    expect(exact).to_be_close_to(0.515625)
    expect(capped).to_be_close_to(0.46875)
    expect(capped > 0 and capped < exact).to_be(true)
    expect(late_cap_heap_library.commandt_test_allocation_count()).to_be(1)
    expect(score(capped_library, 'aaxb', 'ab')).to_be_close_to(capped)
  end)

  it('caps ordinary predecessor work with stack scratch at the default work limit', function()
    local candidate = string.rep('a', 128) .. string.rep('b', 128)
    local exact = reference_score(candidate, 'ab')
    local capped = score(default_library, candidate, 'ab')

    -- Just 256 cells match, but the later b's search back through the a's.
    -- Those predecessor checks must exhaust the default 16,384-unit budget.
    expect(default_library.commandt_test_allocation_count()).to_be(0)
    expect(capped > 0 and capped < exact).to_be(true)
    expect(score(capped_library, candidate, 'ab')).to_be_close_to(capped)
    expect(score(heap_library, candidate, 'ab')).to_be_close_to(capped)
    expect(heap_library.commandt_test_allocation_count()).to_be(1)
  end)

  it('caps ordinary predecessor work on a long line and frees heap scratch', function()
    local candidate = string.rep('a', 8192) .. string.rep('b', 8192)
    local capped = score(default_library, candidate, 'ab')

    -- Exactly 16,384 cells match, so counting cells alone never exceeds the cap
    -- and permits roughly 64 million predecessor checks. Do not enumerate all
    -- alignments here: the best one takes the last a and the first b, while the
    -- greedy fallback takes the first a and the first b.
    local base = (1 / #candidate + 1 / 2) / 2
    local exact = base * (0.75 / 8191 + 1.3)
    local greedy = base * (1 + 0.75 / 8192)
    expect(default_library.commandt_test_allocation_count()).to_be(1)
    expect(capped > 0 and capped < exact).to_be(true)
    expect(capped).to_be_close_to(greedy)
    expect(score(capped_library, candidate, 'ab')).to_be_close_to(capped)
  end)

  it('finishes an exact match when the last budgeted predecessor check proves the rest unnecessary', function()
    local candidate = string.rep('a', 16381) .. 'b'
    local exact = score(default_library, candidate, 'ab')
    local base = (1 / #candidate + 1 / 2) / 2

    -- The matching cells spend 16,382 units. The consecutive last ab wins, and
    -- the second predecessor check proves that every earlier a is worse. That
    -- proof exactly fills the budget: unvisited predecessors do not require
    -- fallback once they have been ruled out.
    expect(default_library.commandt_test_allocation_count()).to_be(1)
    expect(exact).to_be_close_to(base * (0.75 / 16380 + 1.3))
    expect(score(capped_library, candidate, 'ab') < exact).to_be(true)
  end)

  it('can abandon a later ordinary DP row and free heap scratch', function()
    local exact = reference_score('a/aaab', 'aab')
    local capped = score(late_cap_heap_library, 'a/aaab', 'aab')

    -- The first row visits three a's. The cap is exceeded on the second row,
    -- after the score-row pointers have swapped. Greedy chooses a worse path.
    expect(capped > 0 and capped < exact).to_be(true)
    expect(score(capped_library, 'a/aaab', 'aab')).to_be_close_to(capped)
  end)

  it('can abandon a later hidden-dot DP row and use the reachability fallback', function()
    local exact = reference_score('a.b/.bc', '.bc')
    local capped = score(late_cap_heap_library, 'a.b/.bc', '.bc')

    -- Two dot positions and two b positions fill the four-cell budget. Scoring
    -- c reaches the cap. Greedy chose the earlier dot and cannot cross "/.",
    -- so the reachability search must recover the later ".bc" alignment.
    expect(capped > 0 and capped < exact).to_be(true)
    expect(score(capped_library, 'a.b/.bc', '.bc')).to_be_close_to(capped)
  end)

  it('still rejects an ordinary non-match', function()
    expect(reference_score('aba', 'aaa')).to_be(0)
    expect(score(capped_library, 'aba', 'aaa')).to_be(0)
    expect(score(capped_heap_library, 'aba', 'aaa')).to_be(0)
  end)

  it('uses a valid greedy alignment when the query consumes the hidden dot first', function()
    local exact = reference_score('.abc', '.ac')
    local capped = score(capped_library, '.abc', '.ac')
    local capped_heap = score(capped_heap_library, '.abc', '.ac')

    expect(capped > 0).to_be(true)
    expect(capped <= exact + 1e-5).to_be(true)
    expect(capped_heap).to_be_close_to(capped)
  end)

  it('finds a valid hidden-dot alignment even when greedy consumes the wrong dot', function()
    local exact = reference_score('a.b/.c', '.c')
    local capped = score(capped_library, 'a.b/.c', '.c')
    local capped_heap = score(capped_heap_library, 'a.b/.c', '.c')

    -- Greedy takes the ordinary dot and then cannot cross the hidden one.
    -- The fallback's reachability search must instead choose the hidden dot.
    expect(capped > 0).to_be(true)
    expect(capped <= exact + 1e-5).to_be(true)
    expect(capped_heap).to_be_close_to(capped)
  end)

  it('does not accept a subsequence that illegally crosses a hidden dot', function()
    expect(reference_score('a/.b/x/.c/z', '.xz')).to_be(0)
    expect(score(capped_library, 'a/.b/x/.c/z', '.xz')).to_be(0)
    expect(score(capped_heap_library, 'a/.b/x/.c/z', '.xz')).to_be(0)
  end)

  it('can keep a query dot available while crossing several hidden components', function()
    local exact = reference_score('a/.b/.c/z', '.z')
    local capped = score(capped_library, 'a/.b/.c/z', '.z')
    local capped_heap = score(capped_heap_library, 'a/.b/.c/z', '.z')

    expect(capped > 0).to_be(true)
    expect(capped <= exact + 1e-5).to_be(true)
    expect(capped_heap).to_be_close_to(capped)
  end)

  it('stores the completed-match bit for a query exactly 64 characters long', function()
    local candidate = 'a.b/.' .. string.rep('c', 63)
    local query = '.' .. string.rep('c', 63)
    local exact = reference_score(candidate, query)
    local capped = score(capped_library, candidate, query)
    local capped_heap = score(capped_heap_library, candidate, query)

    expect(capped > 0).to_be(true)
    expect(capped <= exact + 1e-5).to_be(true)
    expect(capped_heap).to_be_close_to(capped)
  end)

  it('propagates reachable query prefixes across the 64-bit word boundary', function()
    local candidate = 'a.b/.' .. string.rep('c', 64)
    local query = '.' .. string.rep('c', 64)
    local exact = reference_score(candidate, query)
    local capped = score(capped_library, candidate, query)
    local capped_heap = score(capped_heap_library, candidate, query)

    expect(capped > 0).to_be(true)
    expect(capped <= exact + 1e-5).to_be(true)
    expect(capped_heap).to_be_close_to(capped)
  end)

  it('rejects an illegal hidden-dot crossing after the 64-bit word boundary', function()
    local candidate = 'a.b/.' .. string.rep('c', 64) .. '/.z'
    local query = '.' .. string.rep('c', 64) .. 'z'

    expect(reference_score(candidate, query)).to_be(0)
    expect(score(capped_library, candidate, query)).to_be(0)
    expect(score(capped_heap_library, candidate, query)).to_be(0)
  end)

  it('can cross hidden components without a query dot when always_show_dot_files is true', function()
    local options = { always_show_dot_files = true }
    local exact = reference_score('a/.b', 'ab', options)
    local capped = score(capped_library, 'a/.b', 'ab', options)

    expect(capped > 0).to_be(true)
    expect(capped <= exact + 1e-5).to_be(true)
    expect(score(capped_heap_library, 'a/.b', 'ab', options)).to_be_close_to(capped)
  end)

  it('still excludes later hidden components when never_show_dot_files is true', function()
    local options = { never_show_dot_files = true }
    expect(reference_score('a.b/.c', '.b', options)).to_be(0)
    expect(score(capped_library, 'a.b/.c', '.b', options)).to_be(0)
    expect(score(capped_heap_library, 'a.b/.c', '.b', options)).to_be(0)
  end)

  it('uses unsigned byte indexes in the hidden-dot reachability masks', function()
    local exact = reference_score('a.b/.\255', '.\255')
    local capped = score(capped_library, 'a.b/.\255', '.\255')

    expect(capped > 0).to_be(true)
    expect(capped <= exact + 1e-5).to_be(true)
    expect(score(capped_heap_library, 'a.b/.\255', '.\255')).to_be_close_to(capped)
  end)

  it('respects case folding in the hidden-dot reachability search', function()
    local options = { ignore_case = true }
    local exact = reference_score('a.b/.C', '.c', options)
    local capped = score(capped_library, 'a.b/.C', '.c', options)

    expect(capped > 0).to_be(true)
    expect(capped <= exact + 1e-5).to_be(true)
    expect(score(capped_heap_library, 'a.b/.C', '.c', options)).to_be_close_to(capped)
  end)
end)

-- This supplementary check enumerates small inputs, not random long paths.
-- Failures print the exact candidate/query and build, so they can be copied
-- directly into a named regression above. The explicit tests explain the rules;
-- this check covers combinations of those rules without relying on a seed.
local function all_strings(alphabet, maximum_length)
  local strings = { '' }
  local previous_length = { '' }
  for _ = 1, maximum_length do
    local next_length = {}
    for _, prefix in ipairs(previous_length) do
      for character in alphabet:gmatch('.') do
        local value = prefix .. character
        strings[#strings + 1] = value
        next_length[#next_length + 1] = value
      end
    end
    previous_length = next_length
  end
  return strings
end

describe('exhaustive short-input score comparisons', function()
  it('checks all candidates up to five bytes and queries up to three bytes over "ab/."', function()
    local candidates = all_strings('ab/.', 5)
    local queries = all_strings('ab/.', 3)
    for _, candidate in ipairs(candidates) do
      for _, query in ipairs(queries) do
        local expected = reference_score(candidate, query)
        local exact = score(default_library, candidate, query)
        local heap = score(heap_library, candidate, query)
        local capped = score(capped_library, candidate, query)
        local capped_heap = score(capped_heap_library, candidate, query)
        local late_cap_heap = score(late_cap_heap_library, candidate, query)
        local exact_agrees = math.abs(exact - expected) <= 1e-5
        local heap_agrees = math.abs(heap - expected) <= 1e-5
        local capped_agrees = (capped > 0) == (expected > 0) and capped <= expected + 1e-5
        local capped_heap_agrees = (capped_heap > 0) == (expected > 0) and capped_heap <= expected + 1e-5
        local late_cap_agrees = (late_cap_heap > 0) == (expected > 0) and late_cap_heap <= expected + 1e-5
        if not (exact_agrees and heap_agrees and capped_agrees and capped_heap_agrees and late_cap_agrees) then
          error(
            string.format(
              'candidate=%q, query=%q\nreference=%g, exact=%g, heap=%g, capped=%g, capped_heap=%g, late_cap_heap=%g',
              candidate,
              query,
              expected,
              exact,
              heap,
              capped,
              capped_heap,
              late_cap_heap
            )
          )
        end
      end
    end
  end)
end)
