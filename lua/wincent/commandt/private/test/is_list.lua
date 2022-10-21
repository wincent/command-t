-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local is_list = require('wincent.commandt.private.is_list')

describe('is_list()', function()
  it('identifies an empty list', function()
    expect(is_list({})).to_be(true)
  end)

  it('identifies a non-empty list', function()
    expect(is_list({ 1, 2, 3 })).to_be(true)
    expect(is_list({ 'foo', 'bar', 'baz' })).to_be(true)
  end)

  it('does not identify a non-empty table as a list', function()
    expect(is_list({ foo = true })).to_be(false)
  end)

  it('does not identify other types as lists', function()
    expect(is_list(0)).to_be(false)
    expect(is_list('hello')).to_be(false)
    expect(is_list(false)).to_be(false)
    expect(is_list(nil)).to_be(false)
    expect(is_list(true)).to_be(false)
  end)
end)
