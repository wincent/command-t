-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local UI = require('wincent.commandt.private.ui')

local merge = require('wincent.commandt.private.merge')
local popd = require('wincent.commandt.popd')
local pushd = require('wincent.commandt.pushd')
local relativize = require('wincent.commandt.private.relativize')

local ui = nil

local function file_finder(directory)
  directory = require('wincent.commandt.get_directory')(directory)
  pushd(directory)
  local options = require('wincent.commandt.private.options'):get()
  local finder = require('wincent.commandt.private.finders.file')('.', options)

  ui = UI.new()
  ui:show(
    finder,
    merge(options, {
      name = 'file',
      on_open = function(result)
        return relativize(directory, result)
      end,
      on_close = popd,
    })
  )
end

local function watchman_finder(directory)
  directory = require('wincent.commandt.get_directory')(directory)
  local options = require('wincent.commandt.private.options'):get()
  local finder = require('wincent.commandt.private.finders.watchman')(directory, options)

  ui = UI.new()
  ui:show(
    finder,
    merge(options, {
      name = 'watchman',
      on_open = function(result)
        return relativize(directory, result)
      end,
    })
  )
end

local function finder(name, directory)
  if name == 'file' then
    return file_finder(directory)
  elseif name == 'watchman' then
    return watchman_finder(directory)
  end

  local options = require('wincent.commandt.private.options'):get()
  local config = options.finders[name]
  if config == nil then
    error('commandt.finder(): no finder registered with name ' .. tostring(name))
  end
  local mode = config.mode
  if config.options then
    -- Optionally transform options.
    local report_errors = require('wincent.commandt.private.report_errors')
    local sanitize = require('wincent.commandt.private.options.sanitize')
    local sanitized_options, errors = sanitize(config.options(options))
    report_errors(errors, 'commandt.finder()')
    options = sanitized_options
  end
  if directory ~= nil then
    directory = vim.trim(directory)
  end
  if config.on_directory then
    directory = config.on_directory(directory)
  end
  local finder = nil
  local context = nil
  options.open = function(item, ex_command)
    if config.open then
      config.open(item, ex_command, directory, options, context)
    else
      local sbuffer = require('wincent.commandt.sbuffer')
      sbuffer(item, ex_command)
    end
  end
  if config.candidates then
    finder, context = require('wincent.commandt.private.finders.list')(directory, config.candidates, options)
  else
    finder = require('wincent.commandt.private.finders.exec')(directory, config.command, options, name)
  end
  if config.fallback then
    finder.fallback = require('wincent.commandt.private.finders.fallback')(finder, directory, options)
  end

  -- TODO: fix type smell here. we're merging "mode", a property that exists
  -- inside matcher configs, into the top level, along with "name".
  ui = UI.new()
  ui:show(
    finder,
    merge(options, {
      name = name,
      mode = mode,
      on_close = config.on_close,
    })
  )
end

return finder
