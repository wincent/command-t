-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local fetch = require('wincent.commandt.private.fetch')

describe('fetch()', function()
  it('fetches a value', function()
    expect(fetch({ foo = 'bar' }, 'foo', true)).to_equal('bar')
  end)

  it('returns a default', function()
    expect(fetch({ foo = 'bar' }, 'baz', 'qux')).to_equal('qux')
  end)
end)
