// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <stdbool.h> /* for bool */

// TODO flesh this out; basically make it a container for instance variables
typedef struct {
    bool always_show_dot_files;
    bool never_show_dot_files;
    // etc
} matcher_t;

// TODO: maybe move this somewhere else
// Struct for representing an individual match.
typedef struct {
    // TODO rename this because match doesn't always correspond to a "path"
    const char *path;
    long bitmask;
    float score;
} match_t;

#if 0
// TODO: maybe rename this and make it follow pattern of heap_new()
matcher_t *CommandTMatcher_initialize(
    bool always_show_dot_files,
    bool never_show_dot_files
);

// TODO figure out what the hell these signatures should look like
VALUE CommandTMatcher_sorted_matches_for(int argc, VALUE *argv, VALUE self);
#endif
