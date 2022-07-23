-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local copy = require('wincent.commandt.private.copy')

describe('copy()', function()
  it('copies lists deeply', function()
    local original = {
      { 'foo' },
      { 'bar' },
      { 'baz' },
    }
    local duplicate = copy(original)
    expect(duplicate).to_equal(original)
    expect(duplicate).not_to_be(original)
    expect(duplicate[1]).to_equal(original[1])
    expect(duplicate[1]).not_to_be(original[1])
    expect(duplicate[2]).to_equal(original[2])
    expect(duplicate[2]).not_to_be(original[2])
    expect(duplicate[3]).to_equal(original[3])
    expect(duplicate[3]).not_to_be(original[3])
  end)

  it('copies lists shallowly', function()
    local original = { 'foo', 'bar', 'baz' }
    local duplicate = copy(original)
    expect(duplicate).to_equal(original)
    expect(duplicate).not_to_be(original)
  end)

  it('copies nil', function()
    expect(copy(nil)).to_be(nil)
  end)

  it('copies numbers', function()
    expect(copy(10)).to_be(10)
  end)

  it('copies strings', function()
    expect(copy('foo')).to_be('foo')
  end)

  it('copies tables deeply', function()
    local original = {
      outer = {
        inner = {},
      },
    }
    local duplicate = copy(original)
    expect(duplicate).to_equal(original)
    expect(duplicate).not_to_be(original)
    expect(duplicate.outer).to_equal(original.outer)
    expect(duplicate.outer).not_to_be(original.outer)
    expect(duplicate.outer.inner).to_equal(original.outer.inner)
    expect(duplicate.outer.inner).not_to_be(original.outer.inner)
  end)

  it('copies tables shallowly', function()
    local original = { foo = 'bar', baz = 'qux' }
    local duplicate = copy(original)
    expect(duplicate).to_equal(original)
    expect(duplicate).not_to_be(original)
  end)
end)
