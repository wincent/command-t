/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdbool.h> /* for bool */
#include <stddef.h> /* for size_t */
#include <stdlib.h> /* for NULL */

#include "debug.h"
#include "score.h"

// Use a struct to make passing params during recursion easier.
typedef struct {
    haystack_t *haystack;
    const char *needle_p;
    size_t needle_length;
    size_t *rightmost_match_p; // Rightmost match for each char in needle.
    float max_score_per_char;
    bool always_show_dot_files;
    bool never_show_dot_files;
    bool case_sensitive;
    bool recurse;
    float *memo; // Memoization.
} matchinfo_t;
// TODO: see if can come up with a better name than matchinfo_t

static float recursive_match(
    matchinfo_t *m, // Sharable meta-data.
    size_t haystack_idx, // Where in the path string to start.
    size_t needle_idx, // Where in the needle string to start.
    size_t last_idx, // Location of last matched character.
    float score // Cumulative score so far.
) {
    float *memoized = NULL;
    float seen_score = 0.0f;

    // Iterate over needle.
    for (size_t i = needle_idx; i < m->needle_length; i++) {
        // Iterate over (valid range of) haystack.
        for (size_t j = haystack_idx; j <= m->rightmost_match_p[i]; j++) {
            char c, d;

            // Do we have a memoized result we can return?
            memoized = &m->memo[j * m->needle_length + i];
            if (*memoized != UNSET_SCORE) {
                return *memoized > seen_score ? *memoized : seen_score;
            }
            c = m->needle_p[i];
            d = m->haystack->candidate->contents[j];
            if (d == '.') {
                if (j == 0 || m->haystack->candidate->contents[j - 1] == '/') { // This is a dot-file.
                    int dot_search = c == '.'; // Searching for a dot.
                    if (
                        m->never_show_dot_files ||
                        (!dot_search && !m->always_show_dot_files)
                    ) {
                        return *memoized = 0.0f;
                    }
                }
            } else if (d >= 'A' && d <= 'Z' && !m->case_sensitive) {
                d += 'a' - 'A'; // Add 32 to downcase.
            }

            if (c == d) {
                // Calculate score.
                float score_for_char = m->max_score_per_char;
                size_t distance = j - last_idx;

                if (distance > 1) {
                    float factor = 1.0f;
                    char last = m->haystack->candidate->contents[j - 1];
                    char curr = m->haystack->candidate->contents[j]; // Case matters, so get again.
                    if (last == '/') {
                        factor = 0.9f;
                    } else if (
                        last == '-' ||
                        last == '_' ||
                        last == ' ' ||
                        (last >= '0' && last <= '9')
                    ) {
                        factor = 0.8f;
                    } else if (
                        last >= 'a' && last <= 'z' &&
                        curr >= 'A' && curr <= 'Z'
                    ) {
                        factor = 0.8f;
                    } else if (last == '.') {
                        factor = 0.7f;
                    } else {
                        // If no "special" chars behind char, factor diminishes
                        // as distance from last matched char increases.
                        factor = (1.0f / distance) * 0.75f;
                    }
                    score_for_char *= factor;
                }

                if (j < m->rightmost_match_p[i] && m->recurse) {
                    float sub_score = recursive_match(m, j + 1, i, last_idx, score);
                    if (sub_score > seen_score) {
                        seen_score = sub_score;
                    }
                }
                last_idx = j;
                haystack_idx = last_idx + 1;
                score += score_for_char;
                *memoized = seen_score > score ? seen_score : score;
                if (i == m->needle_length - 1) {
                    // Whole string matched.
                    return *memoized;
                }
                if (!m->recurse) {
                    break;
                }
            }
        }
    }
    return *memoized = score;
}

float commandt_score(haystack_t *haystack, matcher_t *matcher) {
    matchinfo_t m;
    bool compute_bitmasks = haystack->bitmask == UNSET_BITMASK;
    m.haystack = haystack;
    m.needle_p = matcher->needle;
    m.needle_length = matcher->needle_length;
    m.rightmost_match_p = NULL;
    m.max_score_per_char = (1.0f / m.haystack->candidate->length + 1.0f / m.needle_length) / 2;
    m.always_show_dot_files = matcher->always_show_dot_files;
    m.never_show_dot_files = matcher->never_show_dot_files;
    m.case_sensitive = matcher->case_sensitive;
    m.recurse = matcher->recurse;

    // Special case for zero-length search string.
    if (m.needle_length == 0) {
        // Filter out dot files.
        if (m.never_show_dot_files || !m.always_show_dot_files) {
            for (size_t i = 0; i < m.haystack->candidate->length; i++) {
                char c = m.haystack->candidate->contents[i];
                if (c == '.' && (i == 0 || m.haystack->candidate->contents[i - 1] == '/')) {
                    return -1.0f;
                }
            }
        }
    } else {
        if (haystack->bitmask != UNSET_BITMASK) {
            if ((matcher->needle_bitmask & haystack->bitmask) != matcher->needle_bitmask) {
                return 0.0f;
            }
        }

        // Pre-scan string:
        // - Bail if it can't match at all.
        // - Record rightmost match for each character (prune search space).
        // - Record bitmask for haystack to speed up future searches.
        size_t rightmost_match_p[m.needle_length];
        m.rightmost_match_p = rightmost_match_p;
        size_t needle_idx = m.needle_length - 1;
        size_t haystack_len = m.haystack->candidate->length;
        size_t haystack_idx = haystack_len ? haystack_len - 1 : 0;
        long mask = 0;
        if (haystack_len) {
            while (haystack_idx >= needle_idx) {
                char c = m.haystack->candidate->contents[haystack_idx];
                char lower = c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c;
                if (!m.case_sensitive) {
                    c = lower;
                }
                if (compute_bitmasks) {
                    mask |= (1 << (lower - 'a'));
                }

                char d = m.needle_p[needle_idx];
                if (c == d) {
                    rightmost_match_p[needle_idx] = haystack_idx;
                    if (needle_idx == 0) {
                        break;
                    } else {
                        needle_idx--;
                    }
                }

                if (haystack_idx == 0) {
                    break;
                } else {
                    haystack_idx--;
                }
            }
        }
        if (compute_bitmasks) {
            if (haystack_len) {
                // In case we broke out of the loop early, compute rest of mask.
                for (size_t i = 0; i <= haystack_idx; i++) {
                    char c = m.haystack->candidate->contents[i];
                    char lower = c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c;
                    if (!m.case_sensitive) {
                        c = lower;
                    }
                    mask |= (1 << (lower - 'a'));
                }
            }
            haystack->bitmask = mask;
        }
        if (needle_idx > 0) {
            return 0.0f;
        }

        // Prepare for memoization.
        size_t haystack_limit = rightmost_match_p[m.needle_length - 1] + 1;
        size_t memo_size = m.needle_length * haystack_limit;
        float memo[memo_size];
        for (size_t i = 0; i < memo_size; i++) {
            memo[i] = UNSET_SCORE;
        }
        m.memo = memo;
        return recursive_match(&m, 0, 0, 0, 0.0f);
    }
    return 1.0f;
}
