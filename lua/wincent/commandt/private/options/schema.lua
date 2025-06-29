-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local is_table = require('wincent.commandt.private.is_table')
local types = require('wincent.commandt.private.options.types')

local schema = {
  kind = 'table',
  keys = {
    always_show_dot_files = { kind = 'boolean' },
    finders = {
      kind = 'table',
      values = {
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
            optional = true,
          },
          mode = {
            kind = {
              one_of = {
                'file',
                'virtual',
              },
            },
            optional = true,
          },
          on_close = {
            kind = 'function',
            optional = true,
          },
          on_directory = {
            kind = 'function',
            optional = true,
          },
          options = {
            kind = 'function',
            optional = true,
          },
          command = {
            kind = {
              one_of = {
                { kind = 'function' },
                { kind = 'string' },
              },
            },
            optional = true,
          },
          fallback = { kind = 'boolean', optional = true },
          max_files = {
            kind = {
              one_of = {
                { kind = 'function' },
                { kind = 'number' },
              },
            },
            optional = true,
          },
          open = { kind = 'function', optional = true },
        },
      },
      meta = function(t, report)
        if is_table(t) then
          for key, value in pairs(t) do
            if value.candidates and value.command then
              value.command = nil
              report(string.format('%s: `candidates` and `command` should not both be set', key))
            elseif value.candidates == nil and value.command == nil then
              value.candidates = {}
              report(string.format('%s: either `candidates` or `command` should be set', key))
            end

            if value.candidates and value.max_files then
              report(string.format('%s: `max_files` has no effect if `candidates` set', key))
            end
          end
        end
      end,
    },
    height = types.height,
    ignore_case = {
      kind = {
        one_of = {
          {
            kind = 'boolean',
          },
          {
            kind = 'function',
          },
        },
      },
      optional = true,
    },
    mappings = {
      kind = 'table',
      keys = {
        i = {
          kind = 'table',
          values = { kind = 'string' },
        },
        n = {
          kind = 'table',
          values = { kind = 'string' },
        },
      },
    },
    margin = types.margin,
    match_listing = {
      kind = 'table',
      keys = {
        border = types.border,
        icons = {
          kind = {
            one_of = {
              { kind = 'boolean' },
              { kind = 'function' },
            },
          },
        },
        truncate = {
          kind = {
            one_of = {
              'beginning',
              'middle',
              'end',
              'true',
              'false',
              { kind = 'boolean' },
            },
          },
        },
      },
    },
    never_show_dot_files = { kind = 'boolean' },
    order = { kind = { one_of = { 'forward', 'reverse' } } },
    position = { kind = { one_of = { 'bottom', 'center', 'top' } } },
    prompt = {
      kind = 'table',
      keys = {
        border = types.border,
      },
    },
    open = { kind = 'function' },
    root_markers = { kind = 'list', of = { kind = 'string' } },
    scanners = {
      kind = 'table',
      keys = {
        fd = {
          kind = 'table',
          keys = {
            max_files = { kind = 'number' },
          },
          optional = true,
        },
        find = {
          kind = 'table',
          keys = {
            max_files = { kind = 'number' },
          },
          optional = true,
        },
        file = {
          kind = 'table',
          keys = {
            max_files = { kind = 'number' },
          },
          optional = true,
        },
        git = {
          kind = 'table',
          keys = {
            max_files = { kind = 'number' },
            submodules = {
              kind = 'boolean',
              optional = true,
            },
            untracked = {
              kind = 'boolean',
              optional = true,
            },
          },
          meta = function(t)
            if is_table(t) and t.submodules == true and t.untracked == true then
              t.submodules = false
              t.untracked = false
              return '`submodules` and `untracked` should not both be true'
            end
          end,
          optional = true,
        },
        rg = {
          kind = 'table',
          keys = {
            max_files = { kind = 'number' },
          },
          optional = true,
        },
        tag = {
          kind = 'table',
          keys = {
            include_filenames = {
              kind = 'boolean',
              optional = true,
            },
          },
          optional = true,
        },
      },
    },
    selection_highlight = { kind = 'string' },
    smart_case = {
      kind = {
        one_of = {
          {
            kind = 'boolean',
          },
          {
            kind = 'function',
          },
        },
      },
      optional = true,
    },
    threads = {
      kind = 'number',
      optional = true,
    },
    traverse = { kind = { one_of = { 'file', 'pwd', 'none' } } },
  },
  meta = function(t)
    if t.always_show_dot_files == true and t.never_show_dot_files == true then
      t.always_show_dot_files = false
      t.never_show_dot_files = false
      return '`always_show_dot_files` and `never_show_dot_files` should not both be true'
    end
  end,
}

return schema
