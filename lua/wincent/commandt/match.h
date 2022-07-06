/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef MATCH_H
#define MATCH_H

#include <stdbool.h> /* for bool */

#include "commandt.h"

#define UNSET_BITMASK (-1)

float commandt_calculate_match(
    haystack_t *haystack,
    const char *needle,
    long needle_length,
    bool case_sensitive,
    bool always_show_dot_files,
    bool never_show_dot_files,
    bool recurse,
    long needle_bitmask
);

#endif
