// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <ruby.h>

// struct for representing an individual match
typedef struct {
    VALUE   path;
    double  score;
} match_t;

extern void calculate_match(VALUE str,
                            VALUE needle,
                            VALUE case_sensitive,
                            VALUE always_show_dot_files,
                            VALUE never_show_dot_files,
                            VALUE recurse,
                            match_t *out);
