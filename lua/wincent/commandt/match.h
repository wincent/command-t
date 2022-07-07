/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef MATCH_H
#define MATCH_H

#include <stdbool.h> /* for bool */

#include "commandt.h" /* for haystack_t, matcher_t */

#define UNSET_BITMASK (-1)

float commandt_calculate_match(haystack_t *haystack, matcher_t *matcher);

#endif
