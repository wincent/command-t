// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <float.h> /* for DBL_MAX */
#include "match.h"
#include "ext.h"
#include "ruby_compat.h"

#define UNSET DBL_MAX

/**
 * # Notes on memoization
 *
 * We want to store a matrix of `needle_len` rows and `haystack_len` columns so
 * that we can look up the previously computed values for "match of `needle_idx`
 * at `haystack_idx`".
 *
 * Assume `needle_len` and `haystack_len` are 5 and 10 respectively, our 2D grid
 * looks like the following. Given a `needle_idx` and a `haystack_idx`, we can
 * index into this co-ordinate space:
 *
 *         haystack_idx
 *      0 1 2 3 4 5 6 7 8 9
 *     +-------------------+
 *     | | | | | | | | | | | 0
 *     ---------------------
 *     | | | | | | | | | | | 1
 *     ---------------------
 *     | | | | | | | | | | | 2   needle_idx
 *     ---------------------
 *     | | | | | | | | | | | 2
 *     ---------------------
 *     | | | | | | | | | | | 3
 *     +-------------------+
 *
 *  Note, however, that we know there are some cells in the matrix that cannot
 *  possibly represent valid matches, because the needle couldn't entirely fit.
 *  Let's mark these with a `#`:
 *
 *         haystack_idx
 *      0 1 2 3 4 5 6 7 8 9
 *     +-------------------+
 *     | | | | | | |#|#|#|#| 0
 *     ---------------------
 *     |#| | | | | | |#|#|#| 1
 *     ---------------------
 *     |#|#| | | | | | |#|#| 2   needle_idx
 *     ---------------------
 *     |#|#|#| | | | | | |#| 2
 *     ---------------------
 *     |#|#|#|#| | | | | | | 3
 *     +-------------------+
 *
 * Observe that this wasted space is equal to `needle_len ^ 2 - needle_len` (a
 * valid assumption because `needle_len` is always smaller than or equal to
 * `haystack_len`, otherwise our search would short circuit before we even got
 * to the memoization stage). The reason the space relationship here is
 * quadratic can be intuited from the diagram, where you can see how the two
 * triangles in opposite corners could be used to form a square, were it not for
 * the missing slice of length `needle_len`.
 *
 * Also note that we don't actually store a real 2-dimensional array here but
 * rather a single array of size `needle_len * haystack_len`, meaning that a
 * small matrix like this one:
 *
 *      +-----+
 *      |A|B|C|
 *      -------
 *      |D|E|F|
 *      -------
 *      |G|H|I|
 *      +-----+
 *
 * Actually gets stored in memory as:
 *
 *      +-----------------+
 *      |A|B|C|D|E|F|G|H|I|
 *      +-----------------+
 *
 * The math we could use to go from a `haystack_idx`/`needle_idx` pair to an
 * index into this underlying 1-dimensional array could be something like:
 *
 *      const index = needle_idx * haystack_len + needle_idx;
 *
 * Or, if we wanted our table to be rotated by 90 degrees (with `needle_indx`
 * down the side):
 *
 *      const index = haystack_idx * needle_len + haystack_idx;
 *
 *  But note that in the code we're doing neither of those but instead:
 *
 *      const index = needle_idx * needle_len + haystack_idx;
 *
 *  This has a very interesting property of filling up the cells as follows:
 *
 *  - Assume cells contain values "A" through "Z" and then "a" through "z" (ie.
 *    the 30 valid values):
 *
 *    label needle haystack cell         label needle haystack cell
 *           idx     idx                        idx     idx
 *      A     0       0      0             P     0       5      5
 *      B     0       1      1             Q     1       5      10
 *      C     1       1      6             R     2       5      15
 *      D     0       2      2             S     3       5      20
 *      E     1       2      7             T     4       5      25
 *      F     2       2      12            U     1       6      11
 *      G     0       3      3             V     2       6      16
 *      H     1       3      8             W     3       6      21
 *      I     2       3      13            X     4       6      26
 *      J     3       3      1             Y     2       7      17
 *      K     0       4      4             Z     3       7      22
 *      L     1       4      9             a     4       7      27
 *      M     2       4      14            b     3       8      23
 *      N     3       4      19            c     4       8      28
 *      O     4       4      24            d     4       9      29
 *
 *      0 1 2 3 4 5 6 7 8 9
 *     +-------------------+
 *     |A|B|D|G|K|P|C|E|H|L| 0
 *     ---------------------
 *     |Q|U|F|I|M|R|V|Y|J|N| 1
 *     ---------------------
 *     |S|W|Z|b|O|T|X|a|c|d| 2
 *     ---------------------
 *     |#|#|#|#|#|#|#|#|#|#| 2
 *     ---------------------
 *     |#|#|#|#|#|#|#|#|#|#| 3
 *     +-------------------+
 *
 * Note that even the largest values for `needle_idx` and `haystack_idx` do not
 * place us anywhere in the bottom 2 rows, so we can actually avoid allocating
 * them entirely. When `needle_idx` is `needle_len - 1` (ie. the last character
 * in the needle) and `haystack_idx` is `haystack_len - 1` (ie. the last
 * character in the haystack) our index into the one-dimensional storage array
 * is `4 * 5 + 9`, which is 29, and corresponds to the cell containing "d" in
 * the diagram above.
 *
 *      0 1 2 3 4 5 6 7 8 9
 *     +-------------------+
 *     |A|B|D|G|K|P|C|E|H|L| 0
 *     ---------------------
 *     |Q|U|F|I|M|R|V|Y|J|N| 1
 *     ---------------------
 *     |S|W|Z|b|O|T|X|a|c|d| 2
 *     +-------------------+
 *
 * So, if we have a `needle_len` by `haystack_len` grid and corresponding set of
 * values (ie. 5 by 10, or 50 cells in this example), how is it that we are
 * writing to and reading from only a subset of 30 cells (3 rows of 10 cells
 * each) without any collisions? The answer lies in excluding the illegal
 * combinations where the needle cannot fit, which we mentioned above. With this
 * formula for cell assignment, the invalid cells all get packed into the bottom
 * two rows (marked with `#`). These correspond to the triangles in the corners
 * of the original diagrams above.
 *
 * As an additional optimization, note that we do a prescan which provides us
 * with information about the rightmost possible location for the final match of
 * the needle string with the haystack. This means that instead of using
 * `haystack_len` to figure out the range of positions at the end of the
 * haystack that some needle characters could not possibly occupy, we can use a
 * potentially lower `rightmost_match_p` value. For each additional unit that
 * `rightmost_match_p` is below `haystack_len - 1`, we can cross out another
 * section from our grid, meaning that we allocate even less memory:
 *
 *      0 1 2 3 4 5 6 7 8 9
 *     +-------------------+
 *     |A|B|D|G|C|E|H|K|F|I| 0
 *     ---------------------
 *     |L|O|J|M|P|R|N|Q|S|T| 1
 *     +-------------------+
 *
 * (Note that we haven't just eliminated the row here, we've also rearranged
 * the letters. I'll show how this was derived later on.)
 *
 * One way to visualize what's happening here is to go back to our original
 * diagram and number the cells as follows, based on the tabulation we made
 * earlier:
 *
 *         haystack_idx
 *      0 1 2 3 4 5 6 7 8 9
 *     +-------------------+
 *     |A|B|D|G|K|P|#|#|#|#| 0
 *     ---------------------
 *     |#|C|E|H|L|Q|U|#|#|#| 1
 *     ---------------------
 *     |#|#|F|I|M|R|V|Y|#|#| 2  needle_idx
 *     ---------------------
 *     |#|#|#|J|N|S|W|Z|b|#| 3
 *     ---------------------
 *     |#|#|#|#|O|T|X|a|c|d| 4
 *     +-------------------+
 *
 * In other words we fill in from top to bottom, and left to right, avoiding
 * cells which we know should be marked with a "#".
 *
 * Now imagine "chopping off" the corner triangles leaving only the rhomboidal
 * section which contains valid values:
 *
 *     +-----------+
 *     |A|B|D|G|K|P|
 *     ---------------
 *       |C|E|H|L|Q|U|
 *       ---------------
 *         |F|I|M|R|V|Y|
 *         ---------------
 *           |J|N|S|W|Z|b|
 *           ---------------
 *             |O|T|X|a|c|d|
 *             +-----------+
 *
 * And then "straightening" the shape back up into a rectangle using a shear
 * transformation:
 *
 *     +-----------+
 *     |A|B|D|G|K|P|
 *     -------------
 *     |C|E|H|L|Q|U|
 *     -------------
 *     |F|I|M|R|V|Y|
 *     -------------
 *     |J|N|S|W|Z|b|
 *     -------------
 *     |O|T|X|a|c|d|
 *     +-----------+
 *
 * And finally encoding the rectangle using a one-dimensional array:
 *
 *     +-----------------------------------------------------------+
 *     |A|B|D|G|K|P|C|E|H|L|Q|U|F|I|M|R|V|Y|J|N|S|W|Z|b|O|T|X|a|c|d|
 *     +-----------------------------------------------------------+
 *
 * If we additionally apply the `rightmost_match_p`-based trimming that we
 * discussed above, our intermediate states can be reduced to something like:
 *
 *         haystack_idx
 *      0 1 2 3 4 5 6 7 8 9
 *     +-------------------+
 *     |A|B|D|G|#|#|#|#|#|#| 0
 *     ---------------------
 *     |#|C|E|H|K|#|#|#|#|#| 1
 *     ---------------------
 *     |#|#|F|I|L|O|#|#|#|#| 2  needle_idx
 *     ---------------------
 *     |#|#|#|J|M|P|R|#|#|#| 3
 *     ---------------------
 *     |#|#|#|#|N|Q|S|T|#|#| 4
 *     +-------------------+
 *
 * Here our `rightmost_match_p` enforces a lower ceiling (by 2) beneath the one
 * provide by `haystack_len - 1`, which means that we have 10 more cells that
 * become invalid and are marked with "#". Moving on, we get:
 *
 *     +-------+
 *     |A|B|D|G|
 *     ---------
 *     |C|E|H|K|
 *     ---------
 *     |F|I|L|O|
 *     ---------
 *     |J|M|P|R|
 *     ---------
 *     |N|Q|S|T|
 *     +-------+
 *
 * And finally:
 *
 *     +---------------------------------------+
 *     |A|B|D|G|C|E|H|K|F|I|L|O|J|M|P|R|N|Q|S|T|
 *     +---------------------------------------+
 *
 * Which corresponds to the chart from earlier when I first introduced the
 * `rightmost_match_p` concept.
 *
 * These smaller arrays reduce memory usage and may be more likely to fit within
 * a CPU cache. Whether the non-linear access pattern during the execution of
 * the algorithm works well with the cache is an open question, although my
 * benchmarking suggests that the format is working well.
 */

// Use a struct to make passing params during recursion easier.
typedef struct {
    char    *haystack_p;            // Pointer to the path string to be searched.
    long    haystack_len;           // Length of same.
    char    *needle_p;              // Pointer to search string (needle).
    long    needle_len;             // Length of same.
    long    *rightmost_match_p;     // Rightmost match for each char in needle.
    double  max_score_per_char;
    int     always_show_dot_files;  // Boolean.
    int     never_show_dot_files;   // Boolean.
    int     case_sensitive;         // Boolean.
    int     recurse;                // Boolean.
    double  *memo;                  // Memoization.
} matchinfo_t;

double recursive_match(
    matchinfo_t *m,    // Sharable meta-data.
    long haystack_idx, // Where in the path string to start.
    long needle_idx,   // Where in the needle string to start.
    long last_idx,     // Location of last matched character.
    double score       // Cumulative score so far.
) {
    long distance, i, j;
    double score_for_char;

    // Do we have a memoized result we can return?
    double *memoized = &m->memo[needle_idx * m->needle_len + haystack_idx];
    if (*memoized != UNSET) {
        return *memoized;
    }

    // Iterate over needle.
    for (i = needle_idx; i < m->needle_len; i++) {

        // Iterate over (valid range of) haystack.
        for (
            j = haystack_idx;
            j <= m->rightmost_match_p[m->needle_len - 1] - (m->needle_len - i) + 1;
            j++
        ) {
            char c = m->needle_p[i];
            char d = m->haystack_p[j];
            if (d == '.') {
                if (j == 0 || m->haystack_p[j - 1] == '/') { // This is a dot-file.
                    int dot_search = c == '.'; // Searching for a dot.
                    if (dot_search) {
                        m->always_show_dot_files = 1;
                    }
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
                score_for_char = m->max_score_per_char;
                distance = j - last_idx;

                if (distance > 1) {
                    double factor = 1.0;
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

                double sub_score = 0;
                if (j < m->rightmost_match_p[i] && m->recurse) {
                    sub_score = recursive_match(m, j + 1, i, last_idx, score) + score;
                }
                score += score_for_char;
                *memoized = sub_score > score ? sub_score : score;
                haystack_idx++;
                break;
            }
        }
    }
    return *memoized = score;
}

double calculate_match(
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
    double score            = 1.0;
    int compute_bitmasks    = *haystack_bitmask == 0;
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
        if (!m.always_show_dot_files) {
            for (i = 0; i < m.haystack_len; i++) {
                char c = m.haystack_p[i];
                if (c == '.' && (i == 0 || m.haystack_p[i - 1] == '/')) {
                    return 0.0;
                }
            }
        }
    } else if (m.haystack_len > 0) { // Normal case.
        if (*haystack_bitmask) {
            if ((needle_bitmask & *haystack_bitmask) != needle_bitmask) {
                return 0.0;
            }
        }

        // Pre-scan string to see if it matches at all (short-circuits).
        // Record rightmost math match for each character (used to prune search space).
        // Record bitmask for haystack to speed up future searches.
        long rightmost_match_p[m.needle_len];
        m.rightmost_match_p = rightmost_match_p;
        long needle_idx = m.needle_len - 1;
        long mask = 0;
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
        // - Snip off corners.
        // - Valid because we know needle_len < haystack_len from above.
        // - Avoid collisions above with a guard clause.
        long haystack_limit = rightmost_match_p[m.needle_len - 1] + 1;
        long memo_size =
            haystack_limit * m.needle_len -
            (m.needle_len * m.needle_len - m.needle_len);
        double memo[memo_size];
        for (i = 0; i < memo_size; i++) {
            memo[i] = UNSET;
        }
        m.memo = memo;

        score = recursive_match(&m, 0, 0, 0, 0.0);
    }
    return score;
}
