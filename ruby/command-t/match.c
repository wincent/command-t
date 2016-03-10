// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <float.h> /* for DBL_MAX */
#include "match.h"
#include "ext.h"
#include "ruby_compat.h"

#define UNSET_SCORE FLT_MAX

// Use a struct to make passing params during recursion easier.
typedef struct {
    char    *haystack_p;            // Pointer to the path string to be searched.
    long    haystack_len;           // Length of same.
    char    *needle_p;              // Pointer to search string (needle).
    long    needle_len;             // Length of same.
    long    *rightmost_match_p;     // Rightmost match for each char in needle.
    float   max_score_per_char;
    int     always_show_dot_files;  // Boolean.
    int     never_show_dot_files;   // Boolean.
    int     case_sensitive;         // Boolean.
    int     recurse;                // Boolean.
    float   *memo;                  // Memoization.
} matchinfo_t;

float recursive_match(
    matchinfo_t *m,    // Sharable meta-data.
    long haystack_idx, // Where in the path string to start.
    long needle_idx,   // Where in the needle string to start.
    long last_idx,     // Location of last matched character.
    float score        // Cumulative score so far.
) {
    long distance, i, j;
    float *memoized = NULL;
    float score_for_char;
    float seen_score = 0;

    // Iterate over needle.
    for (i = needle_idx; i < m->needle_len; i++) {
        // Iterate over (valid range of) haystack.
        for (j = haystack_idx; j <= m->rightmost_match_p[i]; j++) {
            char c, d;

            // Do we have a memoized result we can return?
            memoized = &m->memo[j * m->needle_len + i];
            if (*memoized != UNSET_SCORE) {
                return *memoized > seen_score ? *memoized : seen_score;
            }
            c = m->needle_p[i];
            d = m->haystack_p[j];
            if (d == '.') {
                if (j == 0 || m->haystack_p[j - 1] == '/') { // This is a dot-file.
                    int dot_search = c == '.'; // Searching for a dot.
                    if (
                        m->never_show_dot_files ||
                        (!dot_search && !m->always_show_dot_files)
                    ) {
                        return *memoized = 0.0;
                    }
                }
            } else if (d >= 'A' && d <= 'Z' && !m->case_sensitive) {
                d += 'a' - 'A'; // Add 32 to downcase.
            }

            if (c == d) {
                // Calculate score.
                float sub_score = 0;
                score_for_char = m->max_score_per_char;
                distance = j - last_idx;

                if (distance > 1) {
                    float factor = 1.0;
                    char last = m->haystack_p[j - 1];
                    char curr = m->haystack_p[j]; // Case matters, so get again.
                    if (last == '/') {
                        factor = 0.9;
                    } else if (
                        last == '-' ||
                        last == '_' ||
                        last == ' ' ||
                        (last >= '0' && last <= '9')
                    ) {
                        factor = 0.8;
                    } else if (
                        last >= 'a' && last <= 'z' &&
                        curr >= 'A' && curr <= 'Z'
                    ) {
                        factor = 0.8;
                    } else if (last == '.') {
                        factor = 0.7;
                    } else {
                        // If no "special" chars behind char, factor diminishes
                        // as distance from last matched char increases.
                        factor = (1.0 / distance) * 0.75;
                    }
                    score_for_char *= factor;
                }

                if (j < m->rightmost_match_p[i] && m->recurse) {
                    sub_score = recursive_match(m, j + 1, i, last_idx, score);
                    if (sub_score > seen_score) {
                        seen_score = sub_score;
                    }
                }
                last_idx = j;
                haystack_idx = last_idx + 1;
                score += score_for_char;
                *memoized = seen_score > score ? seen_score : score;
                if (i == m->needle_len - 1) {
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

float calculate_match(
    VALUE haystack,
    VALUE needle,
    VALUE case_sensitive,
    VALUE always_show_dot_files,
    VALUE never_show_dot_files,
    VALUE recurse,
    long needle_bitmask,
    long *haystack_bitmask
) {
    matchinfo_t m;
    long i;
    float score             = 1.0;
    int compute_bitmasks    = *haystack_bitmask == UNSET_BITMASK;
    m.haystack_p            = RSTRING_PTR(haystack);
    m.haystack_len          = RSTRING_LEN(haystack);
    m.needle_p              = RSTRING_PTR(needle);
    m.needle_len            = RSTRING_LEN(needle);
    m.rightmost_match_p     = NULL;
    m.max_score_per_char    = (1.0 / m.haystack_len + 1.0 / m.needle_len) / 2;
    m.always_show_dot_files = always_show_dot_files == Qtrue;
    m.never_show_dot_files  = never_show_dot_files == Qtrue;
    m.case_sensitive        = (int)case_sensitive;
    m.recurse               = recurse == Qtrue;

    // Special case for zero-length search string.
    if (m.needle_len == 0) {
        // Filter out dot files.
        if (m.never_show_dot_files || !m.always_show_dot_files) {
            for (i = 0; i < m.haystack_len; i++) {
                char c = m.haystack_p[i];
                if (c == '.' && (i == 0 || m.haystack_p[i - 1] == '/')) {
                    return 0.0;
                }
            }
        }
    } else {
        long haystack_limit;
        long memo_size;
        long needle_idx;
        long mask;
        long rightmost_match_p[m.needle_len];

        if (*haystack_bitmask != UNSET_BITMASK) {
            if ((needle_bitmask & *haystack_bitmask) != needle_bitmask) {
                return 0.0;
            }
        }

        // Pre-scan string:
        // - Bail if it can't match at all.
        // - Record rightmost match for each character (prune search space).
        // - Record bitmask for haystack to speed up future searches.
        m.rightmost_match_p = rightmost_match_p;
        needle_idx = m.needle_len - 1;
        mask = 0;
        for (i = m.haystack_len - 1; i >= 0; i--) {
            char c = m.haystack_p[i];
            char lower = c >= 'A' && c <= 'Z' ? c + ('a' - 'A') : c;
            if (!m.case_sensitive) {
                c = lower;
            }
            if (compute_bitmasks) {
                mask |= (1 << (lower - 'a'));
            }

            if (needle_idx >= 0) {
                char d = m.needle_p[needle_idx];
                if (c == d) {
                    rightmost_match_p[needle_idx] = i;
                    needle_idx--;
                }
            }
        }
        if (compute_bitmasks) {
            *haystack_bitmask = mask;
        }
        if (needle_idx != -1) {
            return 0.0;
        }

        // Prepare for memoization.
        haystack_limit = rightmost_match_p[m.needle_len - 1] + 1;
        memo_size = m.needle_len * haystack_limit;
        {
            float memo[memo_size];
            for (i = 0; i < memo_size; i++) {
                memo[i] = UNSET_SCORE;
            }
            m.memo = memo;
            score = recursive_match(&m, 0, 0, 0, 0.0);

#ifdef DEBUG
            fprintf(stdout, "   ");
            for (i = 0; i < m.needle_len; i++) {
                fprintf(stdout, "    %c   ", m.needle_p[i]);
            }
            fprintf(stdout, "\n");
            for (i = 0; i < memo_size; i++) {
                char formatted[8];
                if (i % m.needle_len == 0) {
                    long haystack_idx = i / m.needle_len;
                    fprintf(stdout, "%c: ", m.haystack_p[haystack_idx]);
                }
                if (memo[i] == UNSET_SCORE) {
                    snprintf(formatted, sizeof(formatted), "    -  ");
                } else {
                    snprintf(formatted, sizeof(formatted), " %-.4f", memo[i]);
                }
                fprintf(stdout, "%s", formatted);
                if ((i + 1) % m.needle_len == 0) {
                    fprintf(stdout, "\n");
                } else {
                    fprintf(stdout, " ");
                }
            }
            fprintf(stdout, "Final score: %f\n\n", score);
#endif
        }
    }
    return score;
}
