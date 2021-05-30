// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <stdbool.h> /* for bool */

#define UNSET_BITMASK (-1)

// Struct for representing an individual match.
typedef struct {
    // TODO rename this because match doesn't always correspond to a "path"
    const char *path;
    long bitmask;
    float score;
} match_t;

// TODO maybe namespace globally visible symbols like calculate_match
float calculate_match(
    const char *str,
    const char *needle,
    bool case_sensitive,
    bool always_show_dot_files,
    bool never_show_dot_files,
    bool recurse,
    long needle_bitmask,
    long *haystack_bitmask
);
