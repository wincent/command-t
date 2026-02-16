-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local is_table = require('wincent.commandt.private.is_table')
local types = require('wincent.commandt.private.options.types')

---@alias CommandTOptions {
---  always_show_dot_files?: boolean,
---  finders?: table<string, {
---    candidates?: (fun(): string[]) | string[],
---    mode?: ModeOption,
---    on_close?: fun(),
---    on_directory?: fun(),
---    options?: fun(),
---    command?: fun() | string,
---    fallback?: boolean,
---    max_files?: (fun(): number) | number,
---    open?: fun(),
---  }>,
---  height?: number,
---  ignore_case?: boolean | fun(),
---  ignore_spaces?: boolean,
---  mappings?: MappingsOption,
---  margin?: number,
---  match_listing?: {
---    border?: BorderOption,
---    icons?: boolean | fun(),
---    truncate?: TruncateOption,
---  },
---  never_show_dot_files?: boolean,
---  order?: OrderOption,
---  position?: PositionOption,
---  prompt?: {
---    border?: BorderOption,
---  },
---  open?: fun(),
---  root_markers?: string[],
---  scanners?: {
---    fd?: { max_files?: number },
---    find?: { max_files?: number },
---    file?: { max_files?: number },
---    git?: { max_files?: number, submodules?: boolean, untracked?: boolean },
---    rg?: { max_files?: number },
---    tag?: { include_filenames?: boolean },
---  },
---  selection_highlight?: string,
---  smart_case?: boolean | fun(),
---  threads?: number,
---  traverse?: TraverseOption,
---}

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
          mode = types.mode,
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
    ignore_spaces = { kind = 'boolean' },
    mappings = types.mappings,
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
        truncate = types.truncate,
      },
    },
    never_show_dot_files = { kind = 'boolean' },
    order = types.order,
    position = types.position,
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
    traverse = types.traverse,
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
