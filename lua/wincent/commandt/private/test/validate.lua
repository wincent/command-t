-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local validate = require('wincent.commandt.private.validate')

describe('validate()', function()
  before(function()
    assert(_G.vim == nil)
    _G.vim = {
      inspect = function(value)
        return '<inspect:' .. type(value) .. '>'
      end,
      tbl_flatten = function(t)
        local flattened = {}
        for _, v in ipairs(t) do
          for _, inner in ipairs(v) do
            table.insert(flattened, inner)
          end
        end
        return flattened
      end,
    }
  end)

  after(function()
    _G.vim = nil
  end)

  local spec = {
    kind = 'table',
    keys = {
      foo = { kind = 'boolean' },
      bar = { kind = 'string' },
      foobar = { kind = 'number' },
      baz = { kind = 'function' },
      foobaz = { kind = { one_of = { 'left', 'right' } } },
      qux = {
        kind = 'table',
        values = { kind = 'string' },
      },
      fooqux = {
        kind = 'list',
        of = { kind = 'string' },
      },
      foobarbaz = { kind = 'string' },
    },
  }
  local defaults = {
    foo = true,
    bar = 'text',
    foobar = 100,
    baz = function()
      return 1
    end,
    foobaz = 'right',
    qux = { a = 'first', b = 'second' },
    fooqux = { 'penultimate', 'last' },
    foobarbaz = 'sample',
  }

  it('accepts a valid table', function()
    local options = {
      foo = false,
      bar = 'value',
      foobar = 200,
      baz = function()
        return 2
      end,
      foobaz = 'left',
      qux = { c = 'one', d = 'two' },
      fooqux = { 'thing', 'thong' },
    }
    local errors = validate('', nil, options, spec, defaults)
    expect(errors).to_equal({})

    -- Note that omitting values that have defaults is fine.
    expect(options.foobarbaz).to_be('sample')
  end)

  it('preserves values in a valid table', function()
    local options = {
      foo = false,
      bar = 'value',
      foobar = 200,
      baz = function()
        return 2
      end,
      foobaz = 'left',
      qux = { c = 'one', d = 'two' },
      fooqux = { 'thing', 'thong' },
    }
    validate('', nil, options, spec, defaults)
    expect(options.foo).to_be(false)
    expect(options.bar).to_be('value')
    expect(options.foobar).to_be(200)
    expect(options.baz()).to_be(2)
    expect(options.foobaz).to_be('left')
    expect(options.qux).to_equal({ c = 'one', d = 'two' })
    expect(options.fooqux).to_equal({ 'thing', 'thong' })

    -- Again, omitted value that has a default works.
    expect(options.foobarbaz).to_be('sample')
  end)

  it('reports errors in an invalid table', function()
    local options = {
      foo = 1,
      bar = true,
      foobar = { 1 },
      baz = 'nah',
      foobaz = 'center',
      qux = { c = 100, d = 200 },
      fooqux = false,
    }
    local errors = validate('', nil, options, spec, defaults)
    table.sort(errors)
    expect(errors).to_equal({
      '`bar`: expected string but got boolean',
      '`baz`: expected function but got string',
      '`foo`: expected boolean but got number',
      '`foobar`: expected number but got table',
      '`foobaz`: must be one of <inspect:table>',
      '`fooqux`: expected list but got boolean',
      '`qux.c`: expected string but got number',
      '`qux.d`: expected string but got number',
    })
  end)

  it('corrects errors in an invalid table', function()
    local options = {
      bar = true,
      foobar = { 1 },
      baz = 'nah',
      foobaz = 'center',
      qux = { c = 'one', d = 200 },
    }
    validate('', nil, options, spec, defaults)
    expect(options.foo).to_be(true)
    expect(options.bar).to_be('text')
    expect(options.foobar).to_be(100)
    expect(options.baz()).to_be(1)
    expect(options.foobaz).to_be('right')
    expect(options.qux).to_equal({ c = 'one' }) -- Deletes bad value for `d`.
    expect(options.fooqux).to_equal({ 'penultimate', 'last' })

    -- Again, omitted value with a default.
    expect(options.foobarbaz).to_be('sample')
  end)

  describe('validation of a table with "keys"', function()
    it('validates a valid table', function()
      local spec = {
        kind = 'table',
        keys = {
          a = { kind = 'string' },
          b = { kind = 'number' },
        },
      }
      local defaults = {
        a = 'contents',
        b = 10,
      }
      local options = {
        a = 'foo',
        b = 20,
      }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.a).to_be('foo')
      expect(options.b).to_be(20)
    end)

    it('validates an invalid table', function()
      local spec = {
        kind = 'table',
        keys = {
          a = { kind = 'string' },
          b = { kind = 'number' },
        },
      }
      local defaults = {
        a = 'contents',
        b = 10,
      }
      local options = {
        a = 'valid',
        b = 'invalid',
        c = 'unknown',
      }

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`b`: expected number but got string',
        '<top-level>: unrecognized option c',
      })

      -- Good values are preserved.
      expect(options.a).to_be('valid')

      -- Bad values are replaced.
      expect(options.b).to_be(10)

      -- Unrecognized values are removed.
      expect(options.c).to_be(nil)
    end)

    it('substitutes a missing table with a default', function()
      local spec = {
        kind = 'table',
        keys = {
          data = {
            kind = 'table',
            keys = { foo = 'string' },
          },
        },
      }
      local defaults = {
        data = {
          foo = 'bar',
        },
      }
      local options = {}

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`data`: expected table but got nil',
      })

      -- Sets default.
      expect(options.data).to_equal({ foo = 'bar' })
    end)
  end)

  describe('validating a boolean', function()
    it('accepts a valid boolean', function()
      local spec = {
        kind = 'table',
        keys = {
          force = { kind = 'boolean' },
        },
      }
      local defaults = { force = false }
      local options = { force = true }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.force).to_be(true)

      -- Again, but with `false`.
      options = { force = false }
      errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})
      expect(options.force).to_be(false)
    end)

    it('uses a default for an omitted boolean', function()
      local spec = {
        kind = 'table',
        keys = {
          force = { kind = 'boolean' },
          verbose = { kind = 'boolean' },
        },
      }
      local defaults = {
        force = false,
        verbose = false,
      }
      local options = { force = true }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.force).to_be(true)

      -- Omitted values receive default value.
      expect(options.verbose).to_be(false)
    end)

    it('replaces a bad value when a default is provided', function()
      local spec = {
        kind = 'table',
        keys = {
          force = { kind = 'boolean' },
          verbose = { kind = 'boolean' },
        },
      }
      local defaults = {
        force = false,
        verbose = false,
      }
      local options = {
        force = 'yeah',
        verbose = true,
      }

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`force`: expected boolean but got string',
      })

      -- Good values are preserved.
      expect(options.verbose).to_be(true)

      -- Bad values are replaced with the default value.
      expect(options.force).to_be(false)
    end)

    it('allows an optional boolean to be missing', function()
      local spec = {
        kind = 'table',
        keys = {
          force = {
            kind = 'boolean',
            optional = true,
          },
        },
      }
      local defaults = {}
      local options = {}

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Omitted values are allowed.
      expect(options.force).to_be(nil)

      -- Passed values are preserved.
      options = { force = false }
      errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})
      expect(options.force).to_be(false)
    end)
  end)

  describe('validating a function', function()
    it('accepts a valid function', function()
      local spec = {
        kind = 'table',
        keys = {
          foo = { kind = 'function' },
        },
      }
      local defaults = {
        foo = function()
          return 'FOO!'
        end,
      }
      local options = {
        foo = function()
          return 'FOO?'
        end,
      }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.foo()).to_be('FOO?')
    end)

    it('uses a default for an omitted function', function()
      local spec = {
        kind = 'table',
        keys = {
          foo = { kind = 'function' },
          bar = { kind = 'function' },
        },
      }
      local defaults = {
        foo = function()
          return 'FOO!'
        end,
        bar = function()
          return 'BAR!'
        end,
      }
      local options = {
        bar = function()
          return 'BAR...'
        end,
      }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.bar()).to_be('BAR...')

      -- Omitted values receive default value.
      expect(options.foo()).to_be('FOO!')
    end)

    it('replaces a bad value when a default is provided', function()
      local spec = {
        kind = 'table',
        keys = {
          foo = { kind = 'function' },
          bar = { kind = 'function' },
        },
      }
      local defaults = {
        foo = function()
          return 'FOO!'
        end,
        bar = function()
          return 'BAR!'
        end,
      }
      local options = {
        foo = 'yeah',
        bar = function()
          return 'Bar?'
        end,
      }

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`foo`: expected function but got string',
      })

      -- Good values are preserved.
      expect(options.bar()).to_be('Bar?')

      -- Bad values are replaced with the default value.
      expect(options.foo()).to_be('FOO!')
    end)

    it('allows an optional function to be missing', function()
      local spec = {
        kind = 'table',
        keys = {
          foo = {
            kind = 'function',
            optional = true,
          },
        },
      }
      local defaults = {}
      local options = {}

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Omitted values are allowed.
      expect(options.foo).to_be(nil)

      -- Passed values are preserved.
      options = {
        foo = function()
          return 'a value'
        end,
      }
      errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})
      expect(options.foo()).to_be('a value')
    end)
  end)

  describe('validating a list', function()
    it('accepts a valid list', function()
      local spec = {
        kind = 'table',
        keys = {
          groceries = {
            kind = 'list',
            of = { kind = 'string' },
          },
        },
      }
      local defaults = {
        groceries = { 'milk', 'eggs' },
      }
      local options = {
        groceries = { 'low-carb protein shakes', 'kale candies' },
      }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.groceries).to_equal({
        'low-carb protein shakes',
        'kale candies',
      })
    end)

    it('uses a default for an omitted list', function()
      local spec = {
        kind = 'table',
        keys = {
          groceries = {
            kind = 'list',
            of = { kind = 'string' },
          },
        },
      }
      local defaults = {
        groceries = { 'milk', 'eggs' },
      }
      local options = {}

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Omitted values receive default value.
      expect(options.groceries).to_equal({ 'milk', 'eggs' })
    end)

    it('allows an optional list to be missing', function()
      local spec = {
        kind = 'table',
        keys = {
          groceries = {
            kind = 'list',
            of = { kind = 'string' },
            optional = true,
          },
        },
      }
      local defaults = {}
      local options = {}

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Omitted values are allowed.
      expect(options.groceries).to_be(nil)

      -- Passed values are preserved.
      options = {
        groceries = { 'greek yoghurt', 'chick peas' },
      }
      errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})
      expect(options.groceries).to_equal({ 'greek yoghurt', 'chick peas' })
    end)

    it('replaces a bad value when a default is provided', function()
      local spec = {
        kind = 'table',
        keys = {
          groceries = {
            kind = 'list',
            of = { kind = 'string' },
          },
        },
      }
      local defaults = {
        groceries = { 'milk', 'eggs' },
      }
      local options = {
        groceries = 10,
      }

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`groceries`: expected list but got number',
      })

      -- Bad values are replaced with the default value.
      expect(options.groceries).to_equal({ 'milk', 'eggs' })
    end)

    it('removes bad items from list', function()
      local spec = {
        kind = 'table',
        keys = {
          groceries = {
            kind = 'list',
            of = { kind = 'string' },
          },
        },
      }
      local defaults = {
        groceries = { 'milk', 'eggs' },
      }
      local options = {
        groceries = { 10, 'apples', 5, 'peaches' },
      }

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`groceries[1]`: expected string but got number',
        '`groceries[3]`: expected string but got number',
      })

      -- Bad values are removed
      expect(options.groceries).to_equal({ 'apples', 'peaches' })
    end)
  end)

  describe('validating a number', function()
    it('accepts a valid number', function()
      local spec = {
        kind = 'table',
        keys = {
          iterations = { kind = 'number' },
        },
      }
      local defaults = { iterations = 100 }
      local options = { iterations = 10 }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.iterations).to_be(10)
    end)

    it('uses a default for an omitted number', function()
      local spec = {
        kind = 'table',
        keys = {
          iterations = { kind = 'number' },
        },
      }
      local defaults = { iterations = 100 }
      local options = {}

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Omitted values receive default value.
      expect(options.iterations).to_be(100)
    end)

    it('allows an optional number to be missing', function()
      local spec = {
        kind = 'table',
        keys = {
          iterations = {
            kind = 'number',
            optional = true,
          },
        },
      }
      local defaults = {}
      local options = {}

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Omitted values are allowed.
      expect(options.iterations).to_be(nil)

      -- Passed values are preserved.
      options = {
        iterations = 1000,
      }
      errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})
      expect(options.iterations).to_be(1000)
    end)

    it('replaces a bad value when a default is provided', function()
      local spec = {
        kind = 'table',
        keys = {
          iterations = { kind = 'number' },
        },
      }
      local defaults = {
        iterations = 100,
      }
      local options = {
        iterations = 'many',
      }

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`iterations`: expected number but got string',
      })

      -- Bad values are replaced with the default value.
      expect(options.iterations).to_be(100)
    end)

    it('allows for post-processing with "meta"', function()
      local spec = {
        kind = 'table',
        keys = {
          margin = {
            kind = 'number',
            meta = function(context)
              if context.margin < 100 then
                context.margin = 100
                return { 'should be at least 100' }
              end
            end,
          },
        },
      }
      local defaults = {
        margin = 200,
      }
      local options = {
        margin = 150,
      }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.margin).to_be(150)

      -- Has errors.
      options = {
        margin = 10,
      }
      errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`margin`: should be at least 100',
      })

      -- Values are post-processed.
      expect(options.margin).to_be(100)
    end)
  end)

  describe('validating a string', function()
    it('accepts a valid string', function()
      local spec = {
        kind = 'table',
        keys = {
          name = { kind = 'string' },
        },
      }
      local defaults = { name = 'John' }
      local options = { name = 'Wangari' }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.name).to_be('Wangari')
    end)

    it('uses a default for an omitted string', function()
      local spec = {
        kind = 'table',
        keys = {
          name = { kind = 'string' },
        },
      }
      local defaults = { name = 'John' }
      local options = {}

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Omitted values receive default value.
      expect(options.name).to_be('John')
    end)

    it('allows an optional string to be missing', function()
      local spec = {
        kind = 'table',
        keys = {
          name = {
            kind = 'string',
            optional = true,
          },
        },
      }
      local defaults = {}
      local options = {}

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Omitted values are allowed.
      expect(options.name).to_be(nil)

      -- Passed values are preserved.
      options = {
        name = 'Marie',
      }
      errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})
      expect(options.name).to_be('Marie')
    end)

    it('replaces a bad value when a default is provided', function()
      local spec = {
        kind = 'table',
        keys = {
          name = { kind = 'string' },
        },
      }
      local defaults = { name = 'John' }
      local options = {
        name = false,
      }

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`name`: expected string but got boolean',
      })

      -- Bad values are replaced with the default value.
      expect(options.name).to_be('John')
    end)
  end)

  describe('validation of a table with "values"', function()
    it('validates a valid table', function()
      local spec = {
        kind = 'table',
        values = { kind = 'string' },
      }
      local defaults = {
        sample = 'value',
      }
      local options = {
        a = 'foo',
        b = 'bar',
      }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.a).to_be('foo')
      expect(options.b).to_be('bar')
    end)

    it('validates an invalid table', function()
      local spec = {
        kind = 'table',
        values = { kind = 'string' },
      }
      local defaults = {
        sample = 'value',
      }
      local options = {
        a = 100,
        b = 'valid',
      }

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`a`: expected string but got number',
      })

      -- Good values are preserved, bad values are removed.
      expect(options.a).to_be(nil)
      expect(options.b).to_be('valid')
    end)

    it('substitutes a missing table with a default', function()
      local spec = {
        kind = 'table',
        keys = {
          data = {
            kind = 'table',
            values = { kind = 'string' },
          },
        },
      }
      local defaults = {
        data = {
          a = 'foo',
          b = 'bar',
        },
      }
      local options = {}

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`data`: expected table but got nil',
      })

      -- Sets default.
      expect(options.data).to_equal({
        a = 'foo',
        b = 'bar',
      })
    end)

    it('allows for post-processing with "meta"', function()
      local spec = {
        kind = 'table',
        values = { kind = 'string' },
        meta = function(value)
          if value.foo then
            value.foo = nil
            return { '"foo" is a terrible name for a key' }
          end
        end,
      }
      local defaults = {}
      local options = {
        foo = 'bar',
        baz = 'qux',
      }

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '<top-level>: "foo" is a terrible name for a key',
      })

      -- Values are post-processed.
      expect(options.foo).to_be(nil)
      expect(options.baz).to_be('qux')
    end)
  end)

  describe('validation of "one_of"', function()
    it('validates a valid "enum" list', function()
      local spec = {
        kind = 'table',
        keys = {
          placement = {
            kind = {
              one_of = { 'front', 'back' },
            },
          },
        },
      }
      local defaults = {
        placement = 'back',
      }
      local options = {
        placement = 'front',
      }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.placement).to_be('front')
    end)

    it('validates a invalid "enum" list', function()
      local spec = {
        kind = 'table',
        keys = {
          placement = {
            kind = {
              one_of = { 'front', 'back' },
            },
          },
        },
      }
      local defaults = {
        placement = 'back',
      }
      local options = {
        placement = 'side',
      }

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`placement`: must be one of <inspect:table>',
      })

      -- Bad value is replaced.
      expect(options.placement).to_be('back')
    end)

    it('substitutes a missing "enum" list with a default', function()
      local spec = {
        kind = 'table',
        keys = {
          placement = {
            kind = {
              one_of = { 'front', 'back' },
            },
          },
        },
      }
      local defaults = {
        placement = 'back',
      }
      local options = {}

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`placement`: must be one of <inspect:table>',
      })

      -- Sets default.
      expect(options.placement).to_be('back')
    end)

    it('allows an optional "enum" list to be missing', function()
      local spec = {
        kind = 'table',
        keys = {
          placement = {
            kind = {
              one_of = { 'front', 'back' },
              optional = true,
            },
          },
        },
      }
      local defaults = {}
      local options = {}

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Omitted values are allowed.
      expect(options.placement).to_be(nil)

      -- Passed values are preserved.
      options = {
        placement = 'back',
      }
      errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})
      expect(options.placement).to_be('back')
    end)

    -- Obviously, lots of combinations are possible, but we pick one from the
    -- actual spec we currently use in the app.
    it('validates with a "function"-or-"string" spec', function()
      local spec = {
        kind = 'table',
        keys = {
          command = {
            kind = {
              one_of = {
                { kind = 'function' },
                { kind = 'string' },
              },
            },
          },
        },
      }
      local defaults = {
        command = 'echo',
      }

      -- First, with a string.
      local options = {
        command = 'ls',
      }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.command).to_be('ls')

      -- Now, with a function.
      options = {
        command = function()
          return 'true'
        end,
      }

      -- No errors.
      errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.command()).to_be('true')
    end)

    it('validates with an invalid "function"-or-"string" spec', function()
      local spec = {
        kind = 'table',
        keys = {
          command = {
            kind = {
              one_of = {
                { kind = 'function' },
                { kind = 'string' },
              },
            },
          },
        },
      }
      local defaults = {
        command = 'echo',
      }
      local options = {
        command = false,
      }

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`command`: must be one of <inspect:table>',
      })

      -- Bad value is replaced.
      expect(options.command).to_be('echo')
    end)

    it('substitutes a missing "function"-or-"string" with a default', function()
      local spec = {
        kind = 'table',
        keys = {
          command = {
            kind = {
              one_of = {
                { kind = 'function' },
                { kind = 'string' },
              },
            },
          },
        },
      }
      local defaults = {
        command = 'echo',
      }
      local options = {}

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`command`: must be one of <inspect:table>',
      })

      -- Sets default.
      expect(options.command).to_be('echo')
    end)

    -- Obviously, lots of combinations are possible, but we pick one from the
    -- actual spec we currently use in the app.
    it('validates with a "function"-or-"list" spec', function()
      local spec = {
        kind = 'table',
        keys = {
          candidates = {
            kind = {
              one_of = {
                { kind = 'function' },
                {
                  kind = 'list',
                  of = { kind = 'string' },
                },
              },
            },
          },
        },
      }
      local defaults = {}

      -- First, with a function.
      local options = {
        candidates = function()
          return 'ls'
        end,
      }

      -- No errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.candidates()).to_be('ls')

      -- Now, with a list.
      options = {
        candidates = { 'foo', 'bar', 'baz' },
      }

      -- No errors.
      errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({})

      -- Values are preserved.
      expect(options.candidates).to_equal({ 'foo', 'bar', 'baz' })
    end)

    it('validates with an invalid "function"-or-"list" spec', function()
      local spec = {
        kind = 'table',
        keys = {
          candidates = {
            kind = {
              one_of = {
                { kind = 'function' },
                {
                  kind = 'list',
                  of = { kind = 'string' },
                },
              },
            },
          },
        },
      }
      local defaults = {}

      -- First, with a function.
      local options = {
        candidates = { bad = 'very' },
      }

      -- Has errors.
      local errors = validate('', nil, options, spec, defaults)
      expect(errors).to_equal({
        '`candidates`: must be one of <inspect:table>',
      })

      -- Bad value is replaced.
      expect(options.candidates).to_equal(nil)
    end)
  end)
end)
