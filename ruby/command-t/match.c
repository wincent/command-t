// Copyright 2010-2013 Wincent Colaiuta. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#include <float.h> /* for DBL_MAX */
#include "match.h"
#include "ext.h"
#include "ruby_compat.h"

// use a struct to make passing params during recursion easier
typedef struct {
    char    *haystack_p;            // pointer to the path string to be searched
    long    haystack_len;           // length of same
    char    *needle_p;              // pointer to search string (needle)
    long    needle_len;             // length of same
    double  max_score_per_char;
    int     dot_file;               // boolean: true if str is a dot-file
    int     always_show_dot_files;  // boolean
    int     never_show_dot_files;   // boolean
    double  *memo;                  // memoization
} matchinfo_t;

double recursive_match(matchinfo_t *m,    // sharable meta-data
                       long haystack_idx, // where in the path string to start
                       long needle_idx,   // where in the needle string to start
                       long last_idx,     // location of last matched character
                       double score)      // cumulative score so far
{
    double seen_score = 0;  // remember best score seen via recursion
    int dot_file_match = 0; // true if needle matches a dot-file
    int dot_search = 0;     // true if searching for a dot
    long i, j, distance;
    int found;
    double score_for_char;

    // do we have a memoized result we can return?
    double memoized = m->memo[needle_idx * m->needle_len + haystack_idx];
    if (memoized != DBL_MAX)
        return memoized;

    // bail early if not enough room (left) in haystack for (rest of) needle
    if (m->haystack_len - haystack_idx < m->needle_len - needle_idx) {
        score = 0.0;
        goto memoize;
    }

    for (i = needle_idx; i < m->needle_len; i++) {
        char c = m->needle_p[i];
        if (c == '.')
            dot_search = 1;
        found = 0;

        // similar to above, we'll stop iterating when we know we're too close
        // to the end of the string to possibly match
        for (j = haystack_idx;
             j <= m->haystack_len - (m->needle_len - i);
             j++, haystack_idx++) {
            char d = m->haystack_p[j];
            if (d == '.') {
                if (j == 0 || m->haystack_p[j - 1] == '/') {
                    m->dot_file = 1;        // this is a dot-file
                    if (dot_search)         // and we are searching for a dot
                        dot_file_match = 1; // so this must be a match
                }
            } else if (d >= 'A' && d <= 'Z') {
                d += 'a' - 'A'; // add 32 to downcase
            }

            if (c == d) {
                found = 1;
                dot_search = 0;

                // calculate score
                score_for_char = m->max_score_per_char;
                distance = j - last_idx;

                if (distance > 1) {
                    double factor = 1.0;
                    char last = m->haystack_p[j - 1];
                    char curr = m->haystack_p[j]; // case matters, so get again
                    if (last == '/')
                        factor = 0.9;
                    else if (last == '-' ||
                            last == '_' ||
                            last == ' ' ||
                            (last >= '0' && last <= '9'))
                        factor = 0.8;
                    else if (last >= 'a' && last <= 'z' &&
                            curr >= 'A' && curr <= 'Z')
                        factor = 0.8;
                    else if (last == '.')
                        factor = 0.7;
                    else
                        // if no "special" chars behind char, factor diminishes
                        // as distance from last matched char increases
                        factor = (1.0 / distance) * 0.75;
                    score_for_char *= factor;
                }

                if (++j < m->haystack_len) {
                    // bump cursor one char to the right and
                    // use recursion to try and find a better match
                    double sub_score = recursive_match(m, j, i, last_idx, score);
                    if (sub_score > seen_score)
                        seen_score = sub_score;
                }

                score += score_for_char;
                last_idx = haystack_idx + 1;
                break;
            }
        }

        if (!found) {
            score = 0.0;
            goto memoize;
        }
    }

    if (m->dot_file &&
        (m->never_show_dot_files ||
         (!dot_file_match && !m->always_show_dot_files))) {
        score = 0.0;
        goto memoize;
    }
    score = score > seen_score ? score : seen_score;

memoize:
    m->memo[needle_idx * m->needle_len + haystack_idx] = score;
    return score;
}

void calculate_match(VALUE str,
                     VALUE needle,
                     VALUE always_show_dot_files,
                     VALUE never_show_dot_files,
                     match_t *out)
{
    long i, max;
    double score;
    matchinfo_t m;
    m.haystack_p            = RSTRING_PTR(str);
    m.haystack_len          = RSTRING_LEN(str);
    m.needle_p              = RSTRING_PTR(needle);
    m.needle_len            = RSTRING_LEN(needle);
    m.max_score_per_char    = (1.0 / m.haystack_len + 1.0 / m.needle_len) / 2;
    m.dot_file              = 0;
    m.always_show_dot_files = always_show_dot_files == Qtrue;
    m.never_show_dot_files  = never_show_dot_files == Qtrue;

    // calculate score
    score = 1.0;

    // special case for zero-length search string
    if (m.needle_len == 0) {

        // filter out dot files
        if (!m.always_show_dot_files) {
            for (i = 0; i < m.haystack_len; i++) {
                char c = m.haystack_p[i];

                if (c == '.' && (i == 0 || m.haystack_p[i - 1] == '/')) {
                    score = 0.0;
                    break;
                }
            }
        }
    } else if (m.haystack_len > 0) { // normal case

        // prepare for memoization
        double memo[m.haystack_len * m.needle_len];
        for (i = 0, max = m.haystack_len * m.needle_len; i < max; i++)
            memo[i] = DBL_MAX;
        m.memo = memo;

        score = recursive_match(&m, 0, 0, 0, 0.0);
    }

    // final book-keeping
    out->path  = str;
    out->score = score;
}
