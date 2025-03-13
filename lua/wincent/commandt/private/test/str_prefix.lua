-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local str_prefix = require('wincent.commandt.private.str_prefix')
local mocks = require('wincent.commandt.private.mocks')

describe('str_prefix()', function()
  before(function()
    mocks.vim({
      fn = {
        strwidth = true,
      },
      str_byteindex = true,
      str_utfindex = true,
    })
  end)

  after(function()
    mocks.vim(false)
  end)

  context('in the absence of multi-cell codepoints', function()
    it('returns prefixes of the string', function()
      expect(str_prefix('foobarbazqux', -1)).to_be('')
      expect(str_prefix('foobarbazqux', 0)).to_be('')
      expect(str_prefix('foobarbazqux', 1)).to_be('f')
      expect(str_prefix('foobarbazqux', 3)).to_be('foo')
      expect(str_prefix('foobarbazqux', 11)).to_be('foobarbazqu')
      expect(str_prefix('foobarbazqux', 12)).to_be('foobarbazqux')
      expect(str_prefix('foobarbazqux', 13)).to_be('foobarbazqux')

      -- Now for some single-width non-ASCII.
      expect(str_prefix('cañón', -1)).to_be('')
      expect(str_prefix('cañón', 0)).to_be('')
      expect(str_prefix('cañón', 1)).to_be('c')
      expect(str_prefix('cañón', 2)).to_be('ca')
      expect(str_prefix('cañón', 3)).to_be('cañ')
      expect(str_prefix('cañón', 4)).to_be('cañó')
      expect(str_prefix('cañón', 5)).to_be('cañón')
      expect(str_prefix('cañón', 6)).to_be('cañón')
    end)
  end)

  context('in the presence of multi-cell codepoints', function()
    -- Test using single-wdith codepoints (eg. ñ, ó)
    -- and double-width codepoints (eg. 火, 水, 土)
    it('returns prefixes of the string', function()
      expect(str_prefix('foo 火水土 cañón', -1)).to_be('')
      expect(str_prefix('foo 火水土 cañón', 0)).to_be('')
      expect(str_prefix('foo 火水土 cañón', 1)).to_be('f')
      expect(str_prefix('foo 火水土 cañón', 3)).to_be('foo')
      expect(str_prefix('foo 火水土 cañón', 4)).to_be('foo ')

      -- Note that 5 isn't possible; we end up returning something of length 4.
      expect(str_prefix('foo 火水土 cañón', 5)).to_be('foo ')

      expect(str_prefix('foo 火水土 cañón', 6)).to_be('foo 火')
      expect(str_prefix('foo 火水土 cañón', 7)).to_be('foo 火')
      expect(str_prefix('foo 火水土 cañón', 8)).to_be('foo 火水')
      expect(str_prefix('foo 火水土 cañón', 9)).to_be('foo 火水')
      expect(str_prefix('foo 火水土 cañón', 10)).to_be('foo 火水土')
      expect(str_prefix('foo 火水土 cañón', 11)).to_be('foo 火水土 ')
      expect(str_prefix('foo 火水土 cañón', 12)).to_be('foo 火水土 c')
      expect(str_prefix('foo 火水土 cañón', 13)).to_be('foo 火水土 ca')
      expect(str_prefix('foo 火水土 cañón', 14)).to_be('foo 火水土 cañ')
      expect(str_prefix('foo 火水土 cañón', 15)).to_be('foo 火水土 cañó')
      expect(str_prefix('foo 火水土 cañón', 16)).to_be('foo 火水土 cañón')
      expect(str_prefix('foo 火水土 cañón', 17)).to_be('foo 火水土 cañón')
    end)
  end)
end)
