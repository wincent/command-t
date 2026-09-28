/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include "score.h"

#include <stddef.h> /* for size_t */
#ifdef DEBUG_SCORING
#include <stdio.h> /* for fprintf(), stdout */
#endif
#include <stdlib.h> /* for NULL, free() */

#include "xmalloc.h" /* for xcalloc(), xmalloc() */

// Scoring tunables.
//
// The per-character "factor ladder" (see `factor_for()`) is inherited verbatim
// from the historical scorer, so all of the boundary-preference behaviour ("/"
// beats "_" beats "." etc.) is unchanged. On top of it, a character that matches
// immediately after the previous match (a "consecutive" character, ie. part of a
// contiguous run) is worth `BONUS_CONSECUTIVE`. Because that exceeds every
// boundary bonus, a contiguous substring match dominates a scattered one (eg.
// "com" prefers "command/x" over "c/o/m/x", and "ab" prefers a consecutive "ab"
// over a split match), which also biases matches towards whole filename
// components without needing a separate basename term.
//
// The bonus is a constant (rather than growing with run length) on purpose: it
// keeps the score of a match a function of the matched positions alone, with no
// dependence on the order in which characters were placed. That is what lets the
// dynamic program below find the true maximum with a single value per cell.
#define BONUS_CAMEL 0.8f // camelCase hump.
#define BONUS_SLASH 0.9f // Character follows a "/".
#define BONUS_WORD 0.8f // Character follows "-", "_", " ", or a digit.
#define BONUS_DOT 0.7f // Character follows ".".
#define BONUS_CONSECUTIVE \
    1.3f // Character immediately follows the previous match.

// Longest candidate whose per-query DP scratch is served from the (small) worker
// stack; longer candidates fall back to a single heap allocation so they cannot
// overflow it. See `commandt_score`. (Overridable at build time so tests can
// force the heap path.)
#ifndef SCORE_SCRATCH_STACK
#define SCORE_SCRATCH_STACK 2048
#endif

// Work cap. The exact DP visits one cell per (needle character, matching
// haystack position) pair, so a single degenerate candidate (a long, very
// low-diversity line: minified/generated/base64 buffer content) can make one
// score cost O(needle_length * length). Past this many matched positions we
// abandon the exact DP for a cheap greedy pass, bounding the per-candidate work.
// The threshold is ~25x the worst realistic candidate (a 196-char path scores
// ~250), so no real path or line is ever approximated; only genuinely
// pathological input is. (Overridable at build time so tests can force it.)
#ifndef SCORE_CELL_CAP
#define SCORE_CELL_CAP 16384
#endif

static inline char downcase(char c) {
    return c >= 'A' && c <= 'Z' ? (char)(c | 0x20) : c;
}

// Index of the leftmost "forbidden" dot (a "." at index 0 or after a "/"), or -1
// if the candidate has none. Computed lazily and cached on the haystack (the
// sentinel -2 means "not yet computed"), since it depends only on the candidate
// string and is consulted by both the empty-query dot filter and the scorer's
// dot gate.
static inline ssize_t forbidden_dot_index(haystack_t *haystack) {
    if (haystack->first_dot == -2) {
        const char *s = haystack->candidate->contents;
        size_t len = haystack->candidate->length;
        ssize_t found = -1;
        for (size_t k = 0; k < len; k++) {
            if (s[k] == '.' && (k == 0 || s[k - 1] == '/')) {
                found = (ssize_t)k;
                break;
            }
        }
        haystack->first_dot = found;
    }
    return haystack->first_dot;
}

// The historical per-character factor: how much a match at `haystack_idx` is
// worth relative to `max_score_per_char`, given that the previous matched
// character was at `last_idx`. A distance of 0 or 1 (ie. the very first
// character, or a character immediately following the previous match) is worth
// the full amount; otherwise the factor depends on the character preceding the
// match (a boundary) or decays with the size of the gap.
static inline float factor_for(const char *haystack, size_t j, size_t last_idx) {
    size_t distance = j - last_idx;
    if (distance <= 1) {
        return 1.0f;
    }
    char last = haystack[j - 1];
    char d = haystack[j];

    // Ordered with most common branches first.
    if (last >= 'a' && last <= 'z') {
        if (d >= 'A' && d <= 'Z') {
            return BONUS_CAMEL;
        }
        return (1.0f / distance) * 0.75f;
    } else if (last == '/') {
        return BONUS_SLASH;
    } else if (last == '-' || last == '_' || last == ' ' || (last >= '0' && last <= '9')) {
        return BONUS_WORD;
    } else if (last == '.') {
        return BONUS_DOT;
    }
    // No "special" char behind this one, so the factor diminishes as the gap
    // grows.
    return (1.0f / distance) * 0.75f;
}

// The part of `factor_for()` that does *not* depend on the previous match's
// position: the boundary bonus for a character at `j` (which is a function of
// `haystack[j - 1]` and `haystack[j]` alone). Returns a negative sentinel when
// the character sits in the interior of a word, where the factor instead decays
// with the gap and so genuinely depends on the previous match. Requires j >= 1.
static inline float boundary_factor(const char *haystack, size_t j) {
    char last = haystack[j - 1];
    char d = haystack[j];
    if (last >= 'a' && last <= 'z') {
        if (d >= 'A' && d <= 'Z') {
            return BONUS_CAMEL;
        }
        return -1.0f; // Interior of a word: gap-dependent.
    } else if (last == '/') {
        return BONUS_SLASH;
    } else if (last == '-' || last == '_' || last == ' ' || (last >= '0' && last <= '9')) {
        return BONUS_WORD;
    } else if (last == '.') {
        return BONUS_DOT;
    }
    return -1.0f; // Interior (non-boundary): gap-dependent.
}

// A single greedy left-to-right alignment: match each needle character at the
// earliest position after the previous match. Scores it with the same rules as
// the DP, so the result is one valid alignment's score, hence a lower bound on
// the true (maximum) score. Used only as the work-cap fallback for degenerate
// candidates; being a lower bound, it can only ever under-rank such a candidate,
// never displace a legitimate result.
static float score_greedy(
    const char *haystack,
    size_t haystack_len,
    const char *needle,
    size_t needle_length,
    float base,
    bool ignore_case
) {
    float total = 0.0f;
    size_t last = 0;
    size_t pos = 0;
    for (size_t i = 0; i < needle_length; i++) {
        char nc = needle[i];
        while (pos < haystack_len) {
            char c = haystack[pos];
            char lower = c >= 'A' && c <= 'Z' ? (char)(c | 0x20) : c;
            if ((ignore_case ? lower : c) == nc) {
                break;
            }
            pos++;
        }
        // The needle is a subsequence of the haystack (the pre-scan proved it),
        // so a match is always found before the end.
        float q = (i > 0 && pos == last + 1)
            ? BONUS_CONSECUTIVE
            : factor_for(haystack, pos, i == 0 ? 0 : last);
        total += base * q;
        last = pos;
        pos++;
    }
    return total;
}

// Try the ordinary left-to-right greedy alignment while rejecting any path
// that skips a forbidden dot. Most capped hidden-dot candidates take this cheap
// path and retain the same useful lower-bound score as ordinary capped input.
// `valid` tells the caller whether the returned score belongs to a complete
// alignment or whether the complete fallback below is still needed.
static float score_greedy_with_dots(
    const char *haystack,
    size_t limit,
    const char *needle,
    size_t needle_length,
    float base,
    bool ignore_case,
    bool *valid
) {
    float total = 0.0f;
    size_t last = 0;
    size_t pos = 0;
    *valid = false;
    for (size_t i = 0; i < needle_length; i++) {
        char needle_char = needle[i];
        while (pos < limit) {
            char c = haystack[pos];
            char compared = ignore_case ? downcase(c) : c;
            bool matches = compared == needle_char;
            if (c == '.' && (pos == 0 || haystack[pos - 1] == '/') && !matches) {
                return 0.0f;
            }
            if (matches) {
                break;
            }
            pos++;
        }
        if (pos == limit) {
            return 0.0f;
        }
        float factor = i > 0 && pos == last + 1
            ? BONUS_CONSECUTIVE
            : factor_for(haystack, pos, i == 0 ? 0 : last);
        total += base * factor;
        last = pos++;
    }
    *valid = true;
    return total;
}

// Determine whether a dot-constrained candidate still matches after the exact
// DP reaches its work cap. A bitset tracks every reachable needle-prefix length:
// ordinary characters may be skipped or consumed, while crossing a forbidden
// dot requires the next needle character to be a dot. That query dot may consume
// the current hidden dot or keep searching for a later one. For human-sized
// needles this uses one or two machine words and is linear in candidate length.
static float score_with_dots_fallback(
    const char *haystack,
    size_t limit,
    const char *needle,
    size_t needle_length,
    float base,
    bool ignore_case
) {
    bool greedy_valid;
    float greedy = score_greedy_with_dots(
        haystack, limit, needle, needle_length, base, ignore_case, &greedy_valid
    );
    if (greedy_valid) {
        return greedy;
    }

    size_t words = (needle_length + 64) / 64;
    uint64_t *masks = xcalloc(256 * words, sizeof(uint64_t));
    uint64_t *states = xcalloc(words, sizeof(uint64_t));
    uint64_t *next_states = xmalloc(words * sizeof(uint64_t));

    for (size_t i = 0; i < needle_length; i++) {
        unsigned char c = (unsigned char)needle[i];
        masks[(size_t)c * words + i / 64] |= UINT64_C(1) << (i % 64);
    }
    states[0] = UINT64_C(1); // Zero needle characters matched.

    size_t full_word = needle_length / 64;
    uint64_t full_bit = UINT64_C(1) << (needle_length % 64);
    float result = 0.0f;

    for (size_t pos = 0; pos < limit; pos++) {
        char c = haystack[pos];
        bool forbidden = c == '.' && (pos == 0 || haystack[pos - 1] == '/');
        char compared = ignore_case ? downcase(c) : c;
        uint64_t *mask = masks + (size_t)(unsigned char)compared * words;
        uint64_t carry = 0;

        if (forbidden) {
            bool any = false;
            for (size_t w = 0; w < words; w++) {
                uint64_t eligible = states[w] & mask[w];
                // While the next needle character is a dot, we may either keep
                // searching past this hidden component or consume its dot now.
                next_states[w] = eligible | (eligible << 1) | carry;
                carry = eligible >> 63;
                any = any || next_states[w] != 0;
            }
            if (!any) {
                goto done;
            }
            for (size_t w = 0; w < words; w++) {
                states[w] = next_states[w];
            }
        } else {
            for (size_t w = 0; w < words; w++) {
                uint64_t eligible = states[w] & mask[w];
                uint64_t shifted = (eligible << 1) | carry;
                carry = eligible >> 63;
                states[w] |= shifted;
            }
        }

        if (states[full_word] & full_bit) {
            // Every matched character contributes at least `base * 0.5 / limit`
            // under the scoring ladder. Return that conservative positive lower
            // bound, preserving the capped scorer's under-ranking guarantee.
            result = base * 0.5f * (float)needle_length / (float)limit;
            goto done;
        }
    }

done:
    free(next_states);
    free(states);
    free(masks);
    return result;
}

// Exact forward DP for candidates whose matchable range contains one or more
// forbidden dots. For a non-dot needle character, a transition from predecessor
// `p` to position `j` is valid exactly when `p` is at or after the latest
// forbidden dot before `j`. Dot rows may keep searching across hidden components
// and match a later dot. Other rows advance a segment-start cursor at forbidden
// dots and use the same prefix-maximum optimization as the common scorer.
static float score_with_dots(
    const char *haystack,
    const char *needle,
    size_t needle_length,
    const size_t *rightmost_match,
    size_t limit,
    float base,
    bool ignore_case,
    float threshold,
    float *score_a,
    float *score_b,
    size_t *list_a,
    size_t *list_b,
    const size_t *forbidden,
    size_t forbidden_count
) {
    float *prev_score = score_b, *cur_score = score_a;
    size_t *prev_list = list_b, *cur_list = list_a;
    size_t prev_count = 0, cur_count = 0;
    float row_max = 0.0f;
    size_t cells = 0;

    // Before the first matched character, a non-dot may not skip a forbidden
    // dot. A leading query dot may search across hidden components for the dot
    // that produces the best complete alignment.
    size_t row_end = rightmost_match[0];
    char needle_0 = needle[0];
    if (needle_0 != '.' && forbidden[0] < row_end) {
        row_end = forbidden[0];
    }
    for (size_t j = 0; j <= row_end; j++) {
        char d = haystack[j];
        char compared = ignore_case ? downcase(d) : d;
        if (compared != needle_0) {
            continue;
        }
        if (++cells > SCORE_CELL_CAP) {
            goto capped;
        }
        float score = base * factor_for(haystack, j, 0);
        cur_score[j] = score;
        cur_list[cur_count++] = j;
        if (score > row_max) {
            row_max = score;
        }
    }
    if (cur_count == 0) {
        return 0.0f;
    }
    if (threshold > 0.0f && needle_length > 1) {
        float bound =
            row_max + BONUS_CONSECUTIVE * base * (float)(needle_length - 1);
        if (bound * (1.0f + 1.0e-4f) < threshold) {
            return row_max;
        }
    }

    for (size_t i = 1; i < needle_length; i++) {
        prev_count = cur_count;
        float *score_swap = prev_score;
        prev_score = cur_score;
        cur_score = score_swap;
        size_t *list_swap = prev_list;
        prev_list = cur_list;
        cur_list = list_swap;
        cur_count = 0;

        char needle_i = needle[i];
        size_t segment_start = 0;
        size_t pk = 0;
        // A query dot may keep searching across hidden components and match a
        // later dot, so only non-dot rows enforce segment boundaries.
        size_t forbidden_index = needle_i == '.' ? forbidden_count : 0;
        float prefix_max = 0.0f;
        bool have_prefix = false;
        row_max = 0.0f;

        size_t first_j = prev_list[0] + 1;
        for (size_t j = first_j; j <= rightmost_match[i]; j++) {
            // A forbidden dot at `j` can be matched. It constrains transitions
            // only after the scan advances beyond it.
            while (forbidden_index < forbidden_count &&
                   forbidden[forbidden_index] < j) {
                size_t minimum = forbidden[forbidden_index++];
                while (segment_start < prev_count &&
                       prev_list[segment_start] < minimum) {
                    segment_start++;
                }
                pk = segment_start;
                prefix_max = 0.0f;
                have_prefix = false;
            }

            char d = haystack[j];
            char compared = ignore_case ? downcase(d) : d;
            if (compared != needle_i) {
                continue;
            }
            if (++cells > SCORE_CELL_CAP) {
                goto capped;
            }

            while (pk < prev_count && prev_list[pk] + 2 <= j) {
                float score = prev_score[prev_list[pk]];
                if (!have_prefix || score > prefix_max) {
                    prefix_max = score;
                    have_prefix = true;
                }
                pk++;
            }

            float best = 0.0f;
            if (pk < prev_count && prev_list[pk] == j - 1) {
                best = prev_score[j - 1] + base * BONUS_CONSECUTIVE;
            }

            if (have_prefix) {
                float factor = boundary_factor(haystack, j);
                if (factor >= 0.0f) {
                    float candidate = base * factor + prefix_max;
                    if (candidate > best) {
                        best = candidate;
                    }
                } else {
                    float k = base * 0.75f;
                    for (size_t t = pk; t-- > segment_start;) {
                        if (++cells > SCORE_CELL_CAP) {
                            goto capped;
                        }
                        size_t p = prev_list[t];
                        float gap_term = k / (float)(j - p);
                        if (prefix_max + gap_term <= best) {
                            break;
                        }
                        float candidate = prev_score[p] + gap_term;
                        if (candidate > best) {
                            best = candidate;
                        }
                    }
                }
            }

            if (best > 0.0f) {
                cur_score[j] = best;
                cur_list[cur_count++] = j;
                if (best > row_max) {
                    row_max = best;
                }
            }
        }

        if (cur_count == 0) {
            return 0.0f;
        }
        if (threshold > 0.0f && i < needle_length - 1) {
            float remaining = (float)(needle_length - 1 - i);
            float bound = row_max + BONUS_CONSECUTIVE * base * remaining;
            if (bound * (1.0f + 1.0e-4f) < threshold) {
                return row_max;
            }
        }
    }

    return row_max;

capped:
    return score_with_dots_fallback(
        haystack, limit, needle, needle_length, base, ignore_case
    );
}

float commandt_score_upper_bound(size_t needle_length, size_t candidate_length) {
    if (needle_length == 0 || candidate_length == 0) {
        return 1.0f;
    }
    float base = (1.0f / candidate_length + 1.0f / needle_length) / 2.0f;

    // Best case: every needle character forms a single contiguous run. The first
    // character is worth at most 1.0; each subsequent one at most
    // `BONUS_CONSECUTIVE` (which exceeds every boundary bonus). This is an
    // admissible upper bound: no alignment can score higher, so it is safe to
    // use for pruning.
    return base * (1.0f + BONUS_CONSECUTIVE * (float)(needle_length - 1));
}

float commandt_score(
    haystack_t *haystack, matcher_t *matcher, bool ignore_case, float threshold
) {
    const char *haystack_p = haystack->candidate->contents;
    size_t haystack_len = haystack->candidate->length;
    const char *needle_p = matcher->needle;
    size_t needle_length = matcher->needle_length;
    bool always_show_dot_files = matcher->always_show_dot_files;
    bool never_show_dot_files = matcher->never_show_dot_files;
    bool compute_bitmasks =
        !commandt_haystack_bitmask_computed(haystack->bitmask);

    // Special case for zero-length search string.
    if (needle_length == 0) {
        // The empty query visits every candidate before the user types anything,
        // and again on every redraw while a streaming finder fills in. Seize
        // that pass to compute the bitmask and leading-dot index in one go, so
        // the O(n) mask work happens at finder-open (or is spread across the
        // streaming redraws) rather than spiking on the first keystroke, which
        // can then use the bitmask prefilter instead of scanning every candidate
        // to build the masks itself.
        if (compute_bitmasks) {
            uint32_t mask = HAYSTACK_BITMASK_COMPUTED;
            ssize_t first_dot = -1;
            for (size_t i = 0; i < haystack_len; i++) {
                char c = haystack_p[i];
                char lower = c >= 'A' && c <= 'Z' ? c | 0x20 : c;
                mask |= commandt_haystack_char_bit((unsigned char)lower);
                if (first_dot < 0 && c == '.' &&
                    (i == 0 || haystack_p[i - 1] == '/')) {
                    first_dot = (ssize_t)i;
                }
            }
            haystack->bitmask = mask;
            haystack->first_dot = first_dot;
        }
        // Filter out dot files (using the cached leading-dot index, so repeated
        // empty-query passes don't rescan every candidate).
        if ((never_show_dot_files || !always_show_dot_files) &&
            forbidden_dot_index(haystack) >= 0) {
            return -1.0f;
        }
        return 1.0f;
    }

    if (commandt_haystack_bitmask_computed(haystack->bitmask)) {
        if ((matcher->needle_bitmask & haystack->bitmask) !=
            matcher->needle_bitmask) {
            return 0.0f;
        }
    }

    // Pre-scan string:
    // - Bail if it can't match at all.
    // - Record rightmost match for each character (prune search space).
    // - Record bitmask for haystack to speed up future searches.
    size_t rightmost_match_p[needle_length];
    size_t needle_idx = needle_length - 1;
    size_t haystack_idx = haystack_len ? haystack_len - 1 : 0;
    uint32_t mask = HAYSTACK_BITMASK_COMPUTED;
    bool found_needle = false;
    if (haystack_len) {
        while (haystack_idx >= needle_idx) {
            char c = haystack_p[haystack_idx];
            char lower = c >= 'A' && c <= 'Z' ? c | 0x20 : c;
            if (ignore_case) {
                c = lower;
            }
            if (compute_bitmasks) {
                mask |= commandt_haystack_char_bit((unsigned char)lower);
            }

            char d = needle_p[needle_idx];
            if (c == d) {
                rightmost_match_p[needle_idx] = haystack_idx;
                if (needle_idx == 0) {
                    found_needle = true;
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
                char c = haystack_p[i];
                char lower = c >= 'A' && c <= 'Z' ? c | 0x20 : c;
                mask |= commandt_haystack_char_bit((unsigned char)lower);
            }
        }
        haystack->bitmask = mask;
    }
    if (!found_needle) {
        return 0.0f;
    }

    // Only positions in `[0, limit)` can participate in a match.
    size_t limit = rightmost_match_p[needle_length - 1] + 1;
    float base = (1.0f / haystack_len + 1.0f / needle_length) / 2.0f;

    // Per-candidate scratch, all sized by `limit`: the two DP score rows, the two
    // reachable-position lists, and the forbidden-dot position list. `limit` is
    // bounded by the candidate's length, so for ordinary paths these fit on the
    // stack, but a pathologically long candidate (eg. a minified buffer line)
    // would overflow a worker thread's small stack; past `SCORE_SCRATCH_STACK`
    // we back them with one heap block instead. Released at `done`. (Everything
    // below this point must exit through `done`, not `return`, so the block is
    // freed.)
    float stack_score[2 * SCORE_SCRATCH_STACK];
    size_t stack_list[2 * SCORE_SCRATCH_STACK];
    size_t stack_forbidden[SCORE_SCRATCH_STACK];
    float *score_a, *score_b;
    size_t *list_a, *list_b, *forbidden_positions;
    void *scratch_heap = NULL;
    if (limit <= SCORE_SCRATCH_STACK) {
        score_a = stack_score;
        score_b = stack_score + limit;
        list_a = stack_list;
        list_b = stack_list + limit;
        forbidden_positions = stack_forbidden;
    } else {
        scratch_heap =
            xmalloc(2 * limit * sizeof(float) + 3 * limit * sizeof(size_t));
        score_a = (float *)scratch_heap;
        score_b = score_a + limit;
        list_a = (size_t *)(score_b + limit);
        list_b = list_a + limit;
        forbidden_positions = list_b + limit;
    }
    float result = 0.0f;

    // Dot-file handling. A "forbidden" dot is one that begins a hidden path
    // component (a "." at index 0 or immediately after a "/"). Depending on the
    // configured policy:
    //
    // - `always_show_dot_files`: no constraint.
    // - `never_show_dot_files`: any forbidden dot anywhere in the candidate
    //   excludes it, even if the match ends before that dot.
    // - default: crossing a forbidden dot requires the current needle character
    //   to be a dot. That query dot may keep searching across any number of
    //   hidden components and match a later dot; after it is consumed, another
    //   component requires another query dot.
    //
    // The cached `first_dot` makes the common case (no hidden component in the
    // matchable range) O(1). When a forbidden dot does fall in `[0, limit)`,
    // gather the forbidden positions and route to the separate dot-aware DP,
    // keeping the common scorer free of hidden-dot checks.
    ssize_t first_dot =
        always_show_dot_files ? -1 : forbidden_dot_index(haystack);
    if (first_dot >= 0 && (never_show_dot_files || (size_t)first_dot < limit)) {
        if (never_show_dot_files) {
            result = 0.0f;
            goto done;
        }
        size_t forbidden_count = 0;
        for (size_t k = (size_t)first_dot; k < limit; k++) {
            if (haystack_p[k] == '.' && (k == 0 || haystack_p[k - 1] == '/')) {
                forbidden_positions[forbidden_count++] = k;
            }
        }
        result = score_with_dots(
            haystack_p,
            needle_p,
            needle_length,
            rightmost_match_p,
            limit,
            base,
            ignore_case,
            threshold,
            score_a,
            score_b,
            list_a,
            list_b,
            forbidden_positions,
            forbidden_count
        );
        goto done;
    }

    // Forward dynamic program. `D[i][j]` is the best score for matching
    // `needle[0..i]` with `needle[i]` anchored at haystack position `j`. We keep
    // only the current and previous rows, each stored sparsely as a list of the
    // reachable positions plus a position-indexed score array. Because a
    // character's contribution depends only on its position and the previous
    // match's position (never on run length), a single score per cell suffices
    // to find the global maximum. Each row's reachable positions are appended to
    // its list in ascending order, which the fast path below relies on. The
    // score rows and lists are the `limit`-sized scratch allocated above.
    float *prev_score = score_b, *cur_score = score_a;
    size_t *prev_list = list_b, *cur_list = list_a;
    size_t prev_count = 0, cur_count = 0;

    // `row_max` is the best score in the row just completed. After row `i`, the
    // final score cannot exceed `row_max + BONUS_CONSECUTIVE * base * remaining`
    // (every full alignment's partial through row `i` is at most `row_max`, and
    // each remaining character adds at most `BONUS_CONSECUTIVE * base`). So once
    // that bound falls below `threshold` the candidate cannot enter the results
    // heap and we abandon it, returning `row_max` (positive, so the caller still
    // treats the candidate as a match, but below `threshold`, so it is not
    // selected).
    float row_max = 0.0f;

    // Running count of matched positions processed; past `SCORE_CELL_CAP` we bail
    // to the greedy fallback. See `SCORE_CELL_CAP`.
    size_t cells = 0;

    // Row 0: place needle[0] at each matching position.
    char needle_0 = needle_p[0];
    for (size_t j = 0; j <= rightmost_match_p[0]; j++) {
        char d = haystack_p[j];
        char d_cmp = ignore_case ? downcase(d) : d;
        if (d_cmp != needle_0) {
            continue;
        }
        if (++cells > SCORE_CELL_CAP) {
            goto capped;
        }
        float c = base * factor_for(haystack_p, j, 0);
        cur_score[j] = c;
        cur_list[cur_count++] = j;
        if (c > row_max) {
            row_max = c;
        }
    }
    if (cur_count == 0) {
        result = 0.0f;
        goto done;
    }
    if (threshold > 0.0f && needle_length > 1) {
        float bound =
            row_max + BONUS_CONSECUTIVE * base * (float)(needle_length - 1);
        if (bound * (1.0f + 1.0e-4f) < threshold) {
            result = row_max;
            goto done;
        }
    }

    // Rows 1..needle_length-1.
    for (size_t i = 1; i < needle_length; i++) {
        // Swap: previous row becomes what we just computed.
        prev_count = cur_count;
        float *ts = prev_score;
        prev_score = cur_score;
        cur_score = ts;
        size_t *tl = prev_list;
        prev_list = cur_list;
        cur_list = tl;
        cur_count = 0;

        char needle_i = needle_p[i];

        // `prefix_max` tracks the best previous-row score among positions
        // `p <= j - 2` (ie. eligible non-consecutive predecessors), advanced
        // incrementally as `j` increases. `pk` is how far into `prev_list` it has
        // consumed.
        size_t pk = 0;
        float prefix_max = 0.0f;
        bool have_prefix = false;
        row_max = 0.0f;

        // The leftmost position `needle[i]` could occupy is one past the leftmost
        // reachable predecessor: any `j <= prev_list[0]` has no predecessor below
        // it, so scanning those positions can only ever yield an empty cell.
        size_t first_j = prev_list[0] + 1;
        for (size_t j = first_j; j <= rightmost_match_p[i]; j++) {
            char d = haystack_p[j];
            char d_cmp = ignore_case ? downcase(d) : d;
            if (d_cmp != needle_i) {
                continue;
            }
            if (++cells > SCORE_CELL_CAP) {
                goto capped;
            }

            // Fast path. Fold every eligible non-consecutive predecessor
            // `p <= j - 2` into `prefix_max`. Afterwards `prev_list[pk]` is the
            // first entry `> j - 2`, so it names the consecutive predecessor
            // exactly when it equals `j - 1`.
            while (pk < prev_count && prev_list[pk] + 2 <= j) {
                float s = prev_score[prev_list[pk]];
                if (!have_prefix || s > prefix_max) {
                    prefix_max = s;
                    have_prefix = true;
                }
                pk++;
            }

            float best = 0.0f;

            // Consecutive predecessor at `j - 1` (worth `BONUS_CONSECUTIVE`).
            if (pk < prev_count && prev_list[pk] == j - 1) {
                best = prev_score[j - 1] + base * BONUS_CONSECUTIVE;
            }

            if (have_prefix) {
                float bf = boundary_factor(haystack_p, j);
                if (bf >= 0.0f) {
                    // Boundary bonus is independent of the predecessor, so the
                    // best non-consecutive score just adds it to `prefix_max`.
                    float cand = base * bf + prefix_max;
                    if (cand > best) {
                        best = cand;
                    }
                } else {
                    // Interior gap: contribution `base * 0.75 / (j - p)` shrinks
                    // as the gap grows. Scan predecessors closest-first and stop
                    // once even `prefix_max` plus the (decreasing) gap term can no
                    // longer beat the best found so far.
                    float k = base * 0.75f;
                    for (size_t t = pk; t-- > 0;) {
                        size_t p = prev_list[t];
                        float gap_term = k / (float)(j - p);
                        if (prefix_max + gap_term <= best) {
                            break;
                        }
                        float cand = prev_score[p] + gap_term;
                        if (cand > best) {
                            best = cand;
                        }
                    }
                }
            }

            if (best > 0.0f) {
                cur_score[j] = best;
                cur_list[cur_count++] = j;
                if (best > row_max) {
                    row_max = best;
                }
            }
        }

        if (cur_count == 0) {
            // No way to match needle[0..i]; nothing can extend it either.
            result = 0.0f;
            goto done;
        }
        if (threshold > 0.0f && i < needle_length - 1) {
            float remaining = (float)(needle_length - 1 - i);
            float bound = row_max + BONUS_CONSECUTIVE * base * remaining;
            if (bound * (1.0f + 1.0e-4f) < threshold) {
                result = row_max;
                goto done;
            }
        }
    }

    // The answer is the best score in the final row.
    result = row_max;

#ifdef DEBUG_SCORING
    fprintf(stdout, "needle='%.*s' ", (int)needle_length, needle_p);
    fprintf(stdout, "haystack='%.*s' ", (int)haystack_len, haystack_p);
    fprintf(stdout, "score=%f\n", result);
#endif

    goto done;

capped:
    // Too many matched positions for the exact DP to be worthwhile on this
    // (degenerate) candidate; fall back to a single greedy alignment.
    result = score_greedy(
        haystack_p, haystack_len, needle_p, needle_length, base, ignore_case
    );

done:
    if (scratch_heap) {
        free(scratch_heap);
    }
    return result;
}
