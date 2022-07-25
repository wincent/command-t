/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef SCORE_H
#define SCORE_H

#include <float.h> /* for FLT_MAX */
#include <stdbool.h> /* for bool */

#include "commandt.h" /* for haystack_t, matcher_t */

#define UNSET_BITMASK (-1)
#define UNSET_SCORE FLT_MAX

float commandt_score(haystack_t *haystack, matcher_t *matcher, bool ignore_case);

#endif
