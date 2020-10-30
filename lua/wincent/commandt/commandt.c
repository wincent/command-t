// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <stddef.h> /* for size_t */
#include <stdlib.h> /* for malloc() */

typedef struct {
    size_t count;
    const char **matches;
} matches_t;

/* TODO: delete this, eventually */
int commandt_example_func_that_returns_int() {
    return 1;
}

/* TODO: delete this, eventually */
const char *commandt_example_func_that_returns_str() {
    return "foobar";
}

const char *foo = "foo";
const char *bar = "bar";
const char *baz = "baz";

matches_t commandt_sorted_matches_for(const char *needle) {
    matches_t result;

    result.count = 3;
    // TODO: figure out how to free this (ie. with ffi.gc())
    result.matches = malloc((sizeof (char *)) * result.count);

    result.matches[0] = foo;
    result.matches[1] = bar;
    result.matches[2] = baz;

    return result;
}
