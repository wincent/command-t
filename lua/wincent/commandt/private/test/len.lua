-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local len = require('wincent.commandt.private.len')
local mocks = require('wincent.commandt.private.mocks')

describe('len()', function()
  before(function()
    mocks.vim({
      str_utfindex = true,
    })
  end)

  after(function()
    mocks.vim(false)
  end)

  it('returns the length of an empty string', function()
    expect(len('')).to_be(0)
  end)

  it('returns the length of a string containing only ASCII characters', function()
    expect(len('foobar')).to_be(6)
  end)

  it('returns the length of string containing multi-byte characters', function()
    expect(len('cañón')).to_be(5)
    expect(len('火水土')).to_be(3)
  end)
end)
