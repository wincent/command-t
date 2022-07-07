/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef MATCH_H
#define MATCH_H

#include <float.h> /* for FLT_MAX */

#include "commandt.h" /* for haystack_t, matcher_t */

#define UNSET_BITMASK (-1)
#define UNSET_SCORE FLT_MAX

float commandt_calculate_match(haystack_t *haystack, matcher_t *matcher);

#endif
