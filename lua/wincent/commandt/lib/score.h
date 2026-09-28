/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef SCORE_H
#define SCORE_H

#include <float.h> /* for FLT_MAX */
#include <stdbool.h> /* for bool */
#include <stdint.h> /* for uint32_t */

#include "commandt.h" /* for haystack_t, matcher_t */

// Needle masks use only bits 0..25, so bit 31 can track whether a candidate
// mask has been computed without affecting the subset test.
#define UNSET_HAYSTACK_BITMASK UINT32_C(0)
#define UNSET_NEEDLE_BITMASK UINT32_MAX
#define HAYSTACK_BITMASK_COMPUTED (UINT32_C(1) << 31)

static inline bool commandt_haystack_bitmask_computed(uint32_t bitmask) {
    return (bitmask & HAYSTACK_BITMASK_COMPUTED) != 0;
}

// Map a candidate byte into one of 32 lossy buckets. Uppercase and lowercase
// ASCII letters differ by 32 and therefore share a bucket. Non-letters may
// collide with letters, producing harmless false positives in the prefilter.
// Masking the index makes the 32-bit shift defined while compiling to the same
// wrapping scalar shift used by the historical scorer.
static inline uint32_t commandt_haystack_char_bit(unsigned char c) {
    unsigned index = ((unsigned)c - (unsigned)'a') & 31u;
    return UINT32_C(1) << index;
}

// No cached score usable for narrowing. Also replaces an old zero when
// pre-score pruning skips a candidate after a query replacement.
// Overwritten by scoring before a candidate enters the results heap.
// FLT_MAX is outside the scoring range and finite, as required by -ffast-math.
#define UNSET_SCORE FLT_MAX

/**
 * Scores `haystack` against `matcher`'s normalized needle.
 *
 * Returns 0 for a non-match, or -1 for a hidden candidate excluded by an empty
 * query. With `threshold` set to 0, a positive return value proves a complete
 * match. It is either the exact score or a lower bound from the work-cap
 * fallback; disabling threshold pruning does not disable the work cap.
 *
 * A positive `threshold` is the minimum score needed to enter the full results
 * heap. If the candidate cannot reach it, scoring may stop early and return a
 * positive partial score below the threshold, without proving a complete match.
 * Do not replace that partial score with zero: later query extensions must be
 * able to reconsider the candidate.
 *
 * May fill the candidate's bitmask and dot-index caches, but does not assign
 * `haystack->score`. The matcher stores the return value, using 1.0f for positive
 * results on alphabetical queries. Never returns UNSET_SCORE; see the field's
 * contract for cached values retained by pre-score pruning.
 */
float commandt_score(
    haystack_t *haystack, matcher_t *matcher, bool ignore_case, float threshold
);

/**
 * An admissible upper bound on the score that any candidate of length
 * `candidate_length` could achieve for a needle of length `needle_length`. Used
 * by the matcher to skip candidates that cannot possibly enter the results heap.
 */
float commandt_score_upper_bound(size_t needle_length, size_t candidate_length);

#endif
