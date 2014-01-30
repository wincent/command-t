var timethat = require('timethat');
var Promise  = require('promise');
var sqlite3  = require('sqlite3').verbose();

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
  // In this latter case we can re-use the same code because the "results" param
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
            resolve(typeof result === "undefined" ? value : result);
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

  return DB;
})();

var db = new DB(':memory:');
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
    return new Promise(function(resolve, reject) {
      db._db.serialize(function() {
        for (var i = 1; i < magnitude; i++) {
          if (i === magnitude - 1) {
            // last iteration, set up callback for promise
            statement.run(
              '/home/glh/www', 'some/sub/path/here/' + i,
              function(err) {
                if (err === null) {
                  resolve();
                } else {
                  reject(err);
                }
              }
            );
          } else {
            // business as usual
            statement.run('/home/glh/www', 'some/sub/path/here/' + i);
          }
        }
      });
    });
  })
  .then(function() {
    tick('SELECT');
    return db.all(
      'SELECT path FROM benchmarks WHERE root = ?', '/home/glh/www'
    );
  })
  .done(function(result) {
    tick('Success');
    printTimings();
    //console.log(result);
  }, function(err) {
    tick('Failure');
    console.log('ERR: ' + err);
    printTimings();
  });
