var timethat = require('timethat');
var optimist = require('optimist').wrap(72);

var DB = require('./lib/db').DB;

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

var db = new DB(argv.database);
var magnitude = 400000;
var timings = [];

function tick(description) {
  console.log(description);
  timings.push([description, new Date()]);
}

function printTimings() {
  console.log('Timings:');
  for (var i = 1, max = timings.length; i < max; i++) {
    var description = timings[i - 1][0];
    var start       = timings[i - 1][1];
    var end         = timings[i][1];
    console.log('  ' + description + ' ' + timethat.calc(start, end));
  }

  var start = timings[0][1];
  var end   = timings[timings.length - 1][1];
  console.log('Total: ' + timethat.calc(start, end));
}

tick('Connect');
db.connect()
  .then(function() {
    tick('PRAGMA');
    return db.run('PRAGMA synchronous=0'); // fast and unsafe
  })
  .then(function() {
    tick('CREATE TABLE');
    return db.run(
      'CREATE TABLE IF NOT EXISTS benchmarks (root VARCHAR, path VARCHAR)'
    );
  })
  .then(function() {
    tick('CREATE INDEX');
    return db.run(
      'CREATE INDEX IF NOT EXISTS benchmarks__root__path ' +
      'ON benchmarks (root, path)'
    );
  })
  .then(function() {
    tick('INSERT');
    return db.prepare('INSERT INTO benchmarks VALUES (?, ?)');
  })
  .then(function(statement) {
    var queries = []

    for (var i = 0; i < magnitude; i++) {
      queries.push(['/home/glh/www', 'some/sub/path/here/' + i]);
    }

    return db.bind(queries, statement);
  })
  .then(function() {
    tick('UPDATE');
    return db.prepare('UPDATE benchmarks SET path = ? WHERE path = ?');
  })
  .then(function(statement) {
    var queries = []

    for (var i = 1, max = magnitude / 4; i < max; i += 4) {
      queries.push(['new/path/' + i, 'some/sub/path/here/' + i]);
    }

    return db.bind(queries, statement);
  })
  .then(function() {
    tick('SELECT');
    return db.all(
      'SELECT path FROM benchmarks WHERE root = ?', '/home/glh/www'
    );
  })
  .then(function() {
    tick('DELETE');
    return db.prepare('DELETE FROM benchmarks WHERE path = ?');
  })
  .then(function(statement) {
    var queries = [];

    for (var i = 1, max = magnitude / 4; i < max; i += 4) {
      queries.push(['new/path/' + i]);
    }

    return db.bind(queries, statement);
  })
  .done(function(result) {
    tick('Success');
    printTimings();
  }, function(err) {
    tick('Failure');
    console.log('ERR: ' + err);
    printTimings();
  });
