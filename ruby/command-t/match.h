// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <ruby.h>

extern double calculate_match(
    VALUE str,
    VALUE needle,
    VALUE case_sensitive,
    VALUE always_show_dot_files,
    VALUE never_show_dot_files,
    VALUE compute_all_scorings,
    long needle_bitmask,
    long *haystack_bitmask
);
