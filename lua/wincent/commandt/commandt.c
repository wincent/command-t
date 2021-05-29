// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <stddef.h> /* for size_t */
#include <stdlib.h> /* for malloc() */

#include "heap.h"

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

static const char **buffers = NULL;

static int cmp_score(const void *a, const void *b) {
    return 1;
}

/*void*/int commandt_example_func_that_takes_a_table_of_strings(int count, const char **candidates) {
    // just showing that we can use a function declared in another translation
    // unit.
    heap_t *heap = heap_new(20, cmp_score);

    // TODO: see if we get called with the same ptr if we call with the same
    // table... - nope... different... let's try again
    // with same ffi.new object, they are the same...
    /* static const char **ptr = NULL; */
    /*  */
    /* if (ptr == candidates) { */
    /*     ptr = candidates; */
    /*     return 111; */
    /* } else { */
    /*     ptr = candidates; */
    /*     return 222; */
    /* } */

    // next step will be to see if string pointers stay the same (i think they
    // will) - yes, they are
    /* static const char *ptr = NULL; */
    /* if (ptr != candidates[0]) { */
    /*     ptr = candidates[0]; */
    /*     return 333; */
    /* } else { */
    /*     ptr = candidates[0]; */
    /*     return 444; */
    /* } */

    // similar, but with static
    if (candidates == NULL) {
        return 999;
    } else
    if (buffers != candidates) {
        buffers = candidates;
        return 555;
    } else {
        buffers = candidates;
        return 666;
    }

    /* int i = 0; */
    /* while (1) { */
    /*     if (candidates[i] == 0) { */
    /*         // This shows that Lua NUL-terminates the array for us. */
    /*         break; */
    /*     } */
    /*     i++; */
    /* } */
}

// We can't NUL-terminate this array because 0 is a valid index position;
// terminate it with -1.
const int indices[] = {32, 10, 900, -1, 12};

const int *commandt_example_func_that_returns_table_of_ints() {
    return indices;
}

// TODO
void commandt_buffer_finder() {
    // TODO provide a way to update this
    static const char **candidates[] = {};
}

matches_t commandt_sorted_matches_for(const char *needle) {
    matches_t result;

    result.count = 3;
    result.matches = malloc((sizeof (char *)) * result.count);

    // TODO: show this works with dynamically allocated strings too...
    // although, really, i think we don't want to be allocating anything...
    // rather, let Lua pass the strings to us and we just access them
    result.matches[0] = foo;
    result.matches[1] = bar;
    result.matches[2] = baz;

    return result;
}
