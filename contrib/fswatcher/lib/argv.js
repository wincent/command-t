"use strict";

var optimist = require('optimist').wrap(72);

module.exports.argv = (function() {
  var argv = optimist
    .usage('Usage: $0 --db <:memory:|filename|"">')
    .options('database', {
      alias:    'd',
      default:  ':memory:',
      describe: 'database location\n(:memory:, filename, or "" for anonymous)\n'
    })
    .options('help', {
      alias:    'h',
      describe: 'show usage'
    })
    .options('port', {
      alias:    'p',
      default:  '53493',
      describe: 'listen on port number'
    })
    .argv;

  if (argv.h) {
    optimist.showHelp();
  }

  return argv;
})();

