"use strict";

var Promise = require('promise');
var sqlite3 = require('sqlite3');

// promise-aware wrapper for sqlite3
module.exports.DB = (function() {
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
