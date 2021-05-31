// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <stdbool.h> /* for bool */

#define UNSET_BITMASK (-1)

float commandt_calculate_match(
    const char *haystack,
    const char *needle,
    bool case_sensitive,
    bool always_show_dot_files,
    bool never_show_dot_files,
    bool recurse,
    long needle_bitmask,
    long *haystack_bitmask
);
