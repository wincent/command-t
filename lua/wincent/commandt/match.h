// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <stdbool.h> /* for bool */

#define UNSET_BITMASK (-1)

float commandt_calculate_match(
    // TODO: rename "str"; it is actually a haystack
    const char *str,
    const char *needle,
    bool case_sensitive,
    bool always_show_dot_files,
    bool never_show_dot_files,
    // TODO: think about getting rid of this setting?
    // probably not though... it almost zero complexity
    bool recurse,
    long needle_bitmask,
    long *haystack_bitmask
);
