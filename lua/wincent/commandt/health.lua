-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local health = vim.health -- after: https://github.com/neovim/neovim/pull/18720
  or require('health') -- before: v0.8.x

local path = require('wincent.commandt.private.path')
local lua_build_directory = vim.fn.fnamemodify((path.caller() + '../lib'):normalize(), ':~')
local ruby_build_directory =
  vim.fn.fnamemodify((path.caller() + '../../../../ruby/command-t/ext/command-t'):normalize(), ':~')

local report_info = function()
  health.info('Command-T version: ' .. require('wincent.commandt.version').version)
  health.info('Lua build directory:\n' .. lua_build_directory)
  health.info('Ruby build directory:\n' .. ruby_build_directory)
end

local check_lua_c_library = function()
  health.start('Checking that Lua C library has been built')

  local lib = require('wincent.commandt.private.lib')
  local result, _ = pcall(function()
    lib.epoch()
  end)

  if result then
    health.ok('Library can be `require`-ed and functions called')
  else
    health.error('Could not call functions in library', {
      'Try running `make` from:\n' .. lua_build_directory,
    })
  end
end

local check_external_dependencies = function()
  health.start('Checking for optional external dependencies')

  for executable, finder in pairs({
    find = 'commandt.find_finder',
    git = 'commandt.git_finder',
    rg = 'commandt.rg_finder',
    watchman = 'commandt.watchman_finder',
  }) do
    if vim.fn.executable(executable) == 1 then
      health.ok(string.format('(optional) `%s` binary found', executable))
    else
      health.warn(string.format('(optional) `%s` binary is not in $PATH', executable), {
        string.format('%s requires `%s`', finder, executable),
      })
    end
  end
end

local check_ruby_c_extension = function()
  health.start('Checking that Ruby C extension has been built')

  if vim.fn.has('ruby') == 1 then
    health.ok('Has Ruby support')
  else
    health.warn('No Ruby support')
    return
  end

  if vim.fn.exists(':CommandTLoad') ~= 0 then
    vim.cmd('CommandTLoad')
    if vim.fn.has('ruby') == 1 then
      local result = vim.fn.rubyeval('$command_t && $command_t.class.respond_to?(:guard) ? 1 : 0')
      if result == 1 then
        health.ok('Has working Ruby C extension')
      else
        health.warn('Ruby C extension missing or broken', {
          'Try running `ruby extconf.rb && make` from\n' .. ruby_build_directory,
        })
      end
    end
  else
    health.warn(':CommandTLoad does not exist')
  end
end

return {
  -- Run with `:checkhealth wincent.commandt`
  check = function()
    report_info()
    check_lua_c_library()
    check_external_dependencies()
    check_ruby_c_extension()
  end,
}
