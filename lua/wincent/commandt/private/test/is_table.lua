-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local is_table = require('wincent.commandt.private.is_table')

describe('is_table()', function()
  it('identifies an empty table', function()
    expect(is_table({})).to_be(true)
  end)

  it('identifies a non-empty table', function()
    expect(is_table({ foo = 'bar' })).to_be(true)
  end)

  it('does not identify a list as a table', function()
    expect(is_table({ 1, 2, 3 })).to_be(false)
    expect(is_table({ 'foo', 'bar', 'baz' })).to_be(false)
  end)

  it('does not identify other types as tables', function()
    expect(is_table(0)).to_be(false)
    expect(is_table('hello')).to_be(false)
    expect(is_table(false)).to_be(false)
    expect(is_table(nil)).to_be(false)
    expect(is_table(true)).to_be(false)
  end)
end)
