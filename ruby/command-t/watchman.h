// Copyright 2014 Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <ruby.h>

/**
 * @module CommandT::Watchman::Utils
 *
 * Methods for working with the Watchman binary protocol
 *
 * @see https://github.com/facebook/watchman/blob/master/BSER.markdown
 */

/**
 * Convert an object serialized using the Watchman binary protocol[0] into an
 * unpacked Ruby object
 */
extern VALUE CommandTWatchmanUtils_load(VALUE self, VALUE serialized);

/**
 * Serialize a Ruby object into the Watchman binary protocol format
 */
extern VALUE CommandTWatchmanUtils_dump(VALUE self, VALUE serializable);

/**
 * Issue `query` to the Watchman instance listening on `socket` (a `UNIXSocket`
 * instance) and return the result
 *
 * The query is serialized following the Watchman binary protocol and the
 * result is converted to native Ruby objects before returning to the caller.
 */
extern VALUE CommandTWatchmanUtils_query(VALUE self, VALUE query, VALUE socket);
