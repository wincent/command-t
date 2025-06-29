-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local concat = require('wincent.commandt.private.concat')

describe('concat()', function()
  context('with no params', function()
    it('returns a new empty list', function()
      local result = concat()
      expect(result).to_equal({})
    end)
  end)

  context('with a single list', function()
    it('returns a copy of the list', function()
      local original = { 'foo', 'bar', 'bar' }
      local result = concat(original)
      expect(result).to_equal(original)
      expect(result).not_to_be(original)
    end)
  end)

  context('with multiple lists', function()
    it('concatenates the lists', function()
      local result = concat({ 'foo', 'bar', 'baz' }, { 'qux', false, 9000 })
      expect(result).to_equal({ 'foo', 'bar', 'baz', 'qux', false, 9000 })
    end)
  end)
end)
