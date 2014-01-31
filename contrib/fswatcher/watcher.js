var timethat = require('timethat');
var Promise  = require('promise');
var sqlite3  = require('sqlite3').verbose();

var optimist = require('optimist').wrap(72);
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

// promise-aware wrapper for sqlite3
var DB = (function() {
  function DB(name) {
    this.name = name;
  }

  DB.prototype.connect = function() {
    return new Promise(function(resolve, reject) {
      this._db = new sqlite3.Database(this.name, function(err) {
        if (err === null) {
          resolve();
        } else {
          reject(err);
        }
      });
    }.bind(this));
  }

  // Returns a promise-returning function which can be used to wrap methods with
  // callbacks that take error and results arguments; ie:
  //
  //   callback(err, results)
  //
  // or simply error arguments; ie:
  //
  //   callback(err)
  //
  // In this latter case we can re-use the same code because the 'results' param
  // is simply `undefined`.
  //
  // Some DB methods don't pass a result in the callback and instead use an
  // immediate return value; these are used in the call to the resolver if
  // appropriate.
  function promisify(name) {
    return function() {
      var args = Array.prototype.slice.apply(arguments);

      return new Promise(function(resolve, reject) {
        var value;

        function handler(err, result) {
          if (err === null) {
            resolve(typeof result === 'undefined' ? value : result);
          } else {
            reject(err);
          }
        }

        args.push(handler);
        value = this._db[name].apply(this._db, args);
      }.bind(this));
    };
  }

  DB.prototype.run     = promisify('run');
  DB.prototype.all     = promisify('all');
  DB.prototype.prepare = promisify('prepare');

  // Bind an array of queries to a prepared statement, executing them serially.
  DB.prototype.bind = function(queries, statement) {
    return new Promise(function(resolve, reject) {
      this._db.serialize(function() {
        function handler(err) {
          if (err !== null) {
            reject(err);
          }
        }

        function lastHandler(err, result) {
          if (err === null) {
            resolve(result);
          } else {
            reject(err);
          }
        }

        for (var i = 0, max = queries.length, last = max - 1; i < max; i++) {
          queries[i].push(i === last ? lastHandler : handler);
          statement.run.apply(statement, queries[i]);
        }
      });
    }.bind(this));
  };

  return DB;
})();

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
