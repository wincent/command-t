-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

describe('matcher.c', function()
  context('with an empty scanner', function()
    local lib
    local matcher
    local scanner

    before(function()
      lib = require'wincent.commandt.lib'
      scanner = lib.scanner_new()
      matcher = lib.commandt_matcher_new(scanner, {})
    end)

    after(function()
      scanner = nil -- Allow scanner to be GC'd.
      matcher = nil -- Allow matcher to be GC'd.
    end)

    local match = function(query)
      local results = lib.commandt_matcher_run(matcher, query)
      local strings = {}
      for k = 0, results.count - 1 do
        local str = results.matches[k]
        table.insert(strings, ffi.string(str.contents, str.length))
      end
      return strings
    end

    it('returns an empty list given an empty query', function()
      expect(match('')).to_equal({})
    end)

    it('returns an empty list given a non-empty query', function()
      expect(match('foo')).to_equal({})
    end)
  end)
end)
