-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local sub = require('wincent.commandt.private.sub')
local mocks = require('wincent.commandt.private.mocks')

describe('sub()', function()
  before(function()
    mocks.vim({
      str_byteindex = true,
      str_utfindex = true,
    })
  end)

  after(function()
    mocks.vim(false)
  end)

  context('in the absence of multi-byte codepoints', function()
    it('returns an entire string', function()
      -- Exact range.
      expect(sub('foobarbazqux', 1, 12)).to_be('foobarbazqux')

      -- Same, but expressed using indices relative to end of string.
      expect(sub('foobarbazqux', -12, -1)).to_be('foobarbazqux')

      -- Overshooting end.
      expect(sub('foobarbazqux', 1, 1000)).to_be('foobarbazqux')

      -- Undershooting start.
      expect(sub('foobarbazqux', 0, 12)).to_be('foobarbazqux')
      expect(sub('foobarbazqux', -1000, 12)).to_be('foobarbazqux')
    end)

    it('returns a string prefix', function()
      -- Indices specified relative to start of string.
      expect(sub('foobarbazqux', 1, 6)).to_be('foobar')

      -- Indices specified relative to end of string.
      expect(sub('foobarbazqux', -12, -7)).to_be('foobar')
    end)

    it('returns a string "infix" (ie. internal segment)', function()
      -- Indices specified relative to start of string.
      expect(sub('foobarbazqux', 7, 9)).to_be('baz')

      -- Indices specified relative to end of string.
      expect(sub('foobarbazqux', -6, -4)).to_be('baz')
    end)

    it('returns a string suffix', function()
      -- Indices specified relative to start of string.
      expect(sub('foobarbazqux', 7)).to_be('bazqux')
      expect(sub('foobarbazqux', 7, 12)).to_be('bazqux')

      -- Indices specified relative to end of string.
      expect(sub('foobarbazqux', -6)).to_be('bazqux')
      expect(sub('foobarbazqux', -6, -1)).to_be('bazqux')
    end)
  end)

  context('in the presence of multi-byte codepoints', function()
    -- Test using two-byte codepoints (eg. ñ, ó)
    -- and three-byte codepoints (eg. 火, 水, 土)
    it('returns an entire string', function()
      -- Exact range.
      expect(sub('foo 火水土 cañón', 1, 13)).to_be('foo 火水土 cañón')

      -- Same, but expressed using indices relative to end of string.
      expect(sub('foo 火水土 cañón', -13, -1)).to_be('foo 火水土 cañón')

      -- Overshooting end.
      expect(sub('foo 火水土 cañón', 1, 1000)).to_be('foo 火水土 cañón')

      -- Undershooting start.
      expect(sub('foo 火水土 cañón', 0, 13)).to_be('foo 火水土 cañón')
      expect(sub('foo 火水土 cañón', -1000, 13)).to_be('foo 火水土 cañón')
    end)

    it('returns a string prefix', function()
      -- Indices specified relative to start of string.
      expect(sub('foo 火水土 cañón', 1, 7)).to_be('foo 火水土')

      -- Indices specified relative to end of string.
      expect(sub('foo 火水土 cañón', -13, -7)).to_be('foo 火水土')
    end)

    it('returns a string "infix" (ie. internal segment)', function()
      -- Indices specified relative to start of string.
      expect(sub('foo 火水土 cañón', 5, 7)).to_be('火水土')

      -- Indices specified relative to end of string.
      expect(sub('foo 火水土 cañón', -9, -7)).to_be('火水土')
    end)

    it('returns a string suffix', function()
      -- Indices specified relative to start of string.
      expect(sub('foo 火水土 cañón', 9)).to_be('cañón')
      expect(sub('foo 火水土 cañón', 9, 13)).to_be('cañón')

      -- Indices specified relative to end of string.
      expect(sub('foo 火水土 cañón', -5)).to_be('cañón')
      expect(sub('foo 火水土 cañón', -5, -1)).to_be('cañón')
    end)
  end)
end)
