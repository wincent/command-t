-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local merge = require('wincent.commandt.private.merge')

describe('merge()', function()
  it('merges shallowly', function()
    local merged = merge({ a = 1, b = true, c = 'foo' }, { a = 2, b = true, d = 'bar', e = nil, f = false })
    expect(merged).to_equal({
      a = 2,
      b = true,
      c = 'foo',
      d = 'bar',
      f = false,
    })
  end)

  it('merges deeply', function()
    -- Tables at the same location get merged.
    local merged = merge({
      a = 1,
      b = {
        c = {
          d = 'hai',
          caboose = true,
        },
        extra = true,
      },
      other = 'yeah',
    }, {
      a = 9000,
      b = {
        c = {
          d = 'bye',
        },
        extra = false,
      },
      other = nil,
    })

    -- Note that you can overwrite with `false` but not `nil`, because Lua just
    -- skips over keys with `nil` values.
    expect(merged).to_equal({
      a = 9000,
      b = {
        c = {
          d = 'bye',
          caboose = true,
        },
        extra = false,
      },
      other = 'yeah',
    })

    -- Values of differing types get overwritten.
    merged = merge({
      a = true,
      b = 10,
      c = { 'foo', 'bar' },
      d = {
        nested = 'yep',
      },
      e = 'untouched',
      f = {
        also = 'untouched',
      },
    }, {
      a = 'thing',
      b = false,
      c = 1000,
      d = {
        nested = { 'inner', 'contents' },
      },
      extra = { true },
    })

    expect(merged).to_equal({
      a = 'thing',
      b = false,
      c = 1000,
      d = {
        nested = { 'inner', 'contents' },
      },
      e = 'untouched',
      f = {
        also = 'untouched',
      },
      extra = { true },
    })
  end)
end)
