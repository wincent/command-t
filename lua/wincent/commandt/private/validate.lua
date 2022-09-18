-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local copy = require('wincent.commandt.private.copy')
local is_list = require('wincent.commandt.private.is_list')
local is_table = require('wincent.commandt.private.is_table')

-- Forward declarations.
local validate_boolean = nil
local validate_function = nil
local validate_list = nil
local validate_number = nil
local validate_one_of = nil
local validate_string = nil
local validate_table = nil

local format_path = function(path)
  if path == '' then
    return '<top-level>'
  else
    -- Trim leading "." and enclose in backticks.
    return '`' .. path:sub(2, -1) .. '`'
  end
end

-- Given `'foo.bar.baz'` return `'baz'`.
local last = function(list)
  return list[#list]
end

-- Turn `'foo.bar.baz'` into `{ 'foo', 'bar', 'baz' }`.
local split_option = function(option)
  local segments = {}
  -- Append trailing '.' to make it easier to split.
  for segment in string.gmatch(option .. '.', '([%a%d_]+)%.') do
    table.insert(segments, segment)
  end
  return segments
end

-- config.dry_run: do validation, but don't mutate/reset bad values.
local validate = function(path, context, options, spec, defaults, config)
  config = config or {}
  if spec.kind == 'boolean' then
    return validate_boolean(path, context, options, spec, defaults, config)
  elseif spec.kind == 'function' then
    return validate_function(path, context, options, spec, defaults, config)
  elseif spec.kind == 'list' then
    return validate_list(path, context, options, spec, defaults, config)
  elseif spec.kind == 'number' then
    return validate_number(path, context, options, spec, defaults, config)
  elseif spec.kind == 'string' then
    return validate_string(path, context, options, spec, defaults, config)
  elseif spec.kind == 'table' then
    return validate_table(path, context, options, spec, defaults, config)
  elseif type(spec.kind) == 'table' and type(spec.kind.one_of) == 'table' then
    return validate_one_of(path, context, options, spec.kind, defaults, config)
  else
    -- error('not yet implemented')
    return {}
  end
end

validate_boolean = function(path, context, options, spec, defaults, config)
  if options == nil and type(defaults) == 'boolean' and is_table(context) then
    -- Omitting a value for which we have a default is not an error.
    if not config.dry_run or spec.optional then
      context[last(split_option(path))] = defaults
    end
  elseif options == nil and spec.optional then
    -- Omitting an optional value is not an error.
  elseif type(options) ~= 'boolean' then
    if is_table(context) and type(defaults) == 'boolean' and not config.dry_run then
      context[last(split_option(path))] = defaults
    end
    return {
      string.format('%s: expected boolean but got %s', format_path(path), type(options)),
    }
  end
  return {}
end

validate_function = function(path, context, options, spec, defaults, config)
  if options == nil and type(defaults) == 'function' and is_table(context) then
    -- Omitting a value for which we have a default is not an error.
    if not config.dry_run then
      context[last(split_option(path))] = defaults
    end
  elseif options == nil and spec.optional then
    -- Omitting an optional value is not an error.
  elseif type(options) ~= 'function' then
    if is_table(context) and type(defaults) == 'function' and not config.dry_run then
      context[last(split_option(path))] = defaults
    end
    return {
      string.format('%s: expected function but got %s', format_path(path), type(options)),
    }
  end
  return {}
end

validate_list = function(path, context, options, spec, defaults, config)
  local errors = {}
  if options == nil and is_list(defaults) and is_table(context) then
    -- Omitting a value for which we have a default is not an error.
    if not config.dry_run then
      context[last(split_option(path))] = defaults
    end
  elseif options == nil and spec.optional then
    -- Omitting an optional value is not an error.
  elseif not is_list(options) then
    if is_table(context) and is_list(defaults) and not config.dry_run then
      context[last(split_option(path))] = defaults
    end
    table.insert(errors, string.format('%s: expected list but got %s', format_path(path), type(options)))
  else
    local i = 1 -- For iterating over list.
    local original_index = 1 -- For error reporting.
    while i <= #options do
      local value = options[i]
      -- TODO: handle this [] syntax elsewhere
      local item_errors =
        validate(path .. '[' .. tostring(original_index) .. ']', context, value, spec.of, defaults, config)
      if #item_errors > 0 then
        for _, err in ipairs(item_errors) do
          table.insert(errors, err)
        end
        table.remove(options, i)
      else
        i = i + 1
      end
      original_index = original_index + 1
    end
  end
  return errors
end

validate_number = function(path, context, options, spec, defaults, config)
  local errors = {}
  if options == nil and type(defaults) == 'number' and is_table(context) then
    -- Omitting a value for which we have a default is not an error.
    if not config.dry_run then
      context[last(split_option(path))] = defaults
    end
  elseif options == nil and spec.optional then
    -- Omitting an optional value is not an error.
  elseif type(options) ~= 'number' then
    if is_table(context) and type(defaults) == 'number' and not config.dry_run then
      context[last(split_option(path))] = defaults
    end
    errors = {
      string.format('%s: expected number but got %s', format_path(path), type(options)),
    }
  end
  if spec.meta and is_table(context) then
    local err = spec.meta(config.dry_run and copy(context) or context)
    if err then
      for _, e in ipairs(err) do
        table.insert(errors, string.format('%s: %s', format_path(path), e))
      end
    end
  end
  return errors
end

validate_one_of = function(path, context, options, spec, defaults, config)
  for _, candidate in ipairs(spec.one_of) do
    if type(candidate) == 'string' and options == candidate then
      return {}
    elseif type(candidate) == 'table' then
      local errors = validate(path, context, options, candidate, defaults, { dry_run = true })
      if #errors == 0 and options ~= nil then
        return {}
      end
    end
  end
  if options == nil and spec.optional then
    -- Omitting an optional value is not an error.
    return {}
  end
  if is_table(context) and not config.dry_run then
    context[last(split_option(path))] = defaults
  end
  return {
    string.format('%s: must be one of %s', format_path(path), vim.inspect(spec.one_of)),
  }
end

validate_string = function(path, context, options, spec, defaults, config)
  if options == nil and type(defaults) == 'string' and is_table(context) then
    -- Omitting a value for which we have a default is not an error.
    if not config.dry_run then
      context[last(split_option(path))] = defaults
    end
  elseif options == nil and spec.optional then
    -- Omitting an optional value is not an error.
  elseif type(options) ~= 'string' then
    if is_table(context) and type(defaults) == 'string' and not config.dry_run then
      context[last(split_option(path))] = defaults
    end
    return {
      string.format('%s: expected string but got %s', format_path(path), type(options)),
    }
  end
  return {}
end

validate_table = function(path, context, options, spec, defaults, config)
  local errors = {}
  if spec.keys ~= nil then
    -- This should be a record-like table. Look for specific keys.
    if is_table(options) then
      for key, value_spec in pairs(spec.keys) do
        if options[key] == nil and value_spec.optional then
          -- Not an error.
        else
          table.insert(
            errors,
            validate(path .. '.' .. key, options, options[key], value_spec, defaults and defaults[key], config)
          )
        end
      end
      for key, _ in pairs(options) do
        if spec.keys[key] == nil then
          options[key] = nil
          table.insert(errors, {
            string.format('%s: unrecognized option %s', format_path(path), key),
          })
        end
      end
    else
      if is_table(context) and type(defaults) == 'table' and not config.dry_run then
        context[last(split_option(path))] = defaults
      end
      table.insert(errors, { string.format('%s: expected table but got %s', format_path(path), type(options)) })
    end
  elseif spec.values ~= nil then
    -- This should be a dictionary-like table. Accept arbitrary keys, validate the values.
    if is_table(options) then
      for key, value in pairs(options) do
        local err = validate(path .. '.' .. key, options, value, spec.values, nil, config)
        if #err > 0 then
          if not config.dry_run then
            options[key] = nil
          end
          table.insert(errors, err)
        end
      end
    else
      if is_table(context) and type(defaults) == 'table' and not config.dry_run then
        context[last(split_option(path))] = defaults
      end
      table.insert(errors, { string.format('%s: expected table but got %s', format_path(path), type(options)) })
    end
  end
  if spec.meta then
    local err = spec.meta(config.dry_run and copy(options) or options)
    if err then
      for _, e in ipairs(err) do
        table.insert(errors, { string.format('%s: %s', format_path(path), e) })
      end
    end
  end
  return vim.tbl_flatten(errors)
end

return validate
