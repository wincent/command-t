local health = vim.health or require'health'

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
    -- health.report_warn('example', { 'advice' })

    -- TODO: check for Watchman, Git, rg etc.
  end,
}
