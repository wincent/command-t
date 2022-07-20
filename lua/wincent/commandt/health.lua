local health = vim.health -- after: https://github.com/neovim/neovim/pull/18720
  or require('health') -- before: v0.8.x

return {
  -- Run with `:checkhealth wincent.commandt`
  check = function()
    health.report_start('Checking that C library has been built')

    local path = require('wincent.commandt.private.path')
    local build_directory = (path.caller() + '../lib'):normalize()

    health.report_info('Build directory is:\n' .. build_directory)

    local lib = require('wincent.commandt.private.lib')
    local result, _ = pcall(function()
      lib.commandt_epoch()
    end)

    if result then
      health.report_ok('library can be `require`-ed and functions called')
    else
      health.report_error('could not call functions in library', {
        'Try running `make` from:\n' .. build_directory,
      })
    end

    health.report_start('Checking for optional external dependencies')

    for executable, finder in pairs({
      find = 'commandt.find_finder',
      git = 'commandt.git_finder',
      rg = 'commandt.rg_finder',
      watchman = 'commandt.watchman_finder',
    }) do
      if vim.fn.executable(executable) == 1 then
        health.report_ok(string.format('(optional) `%s` binary found', executable))
      else
        health.report_warn(string.format('(optional) `%s` binary is not in $PATH', executable), {
          string.format('%s requires `%s`', finder, executable),
        })
      end
    end
  end,
}
