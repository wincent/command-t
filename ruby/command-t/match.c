// Copyright 2010 Wincent Colaiuta. All rights reserved.
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

#include <ctype.h>
#include <string.h>
#include "match.h"
#include "ext.h"
#include "ruby_compat.h"

// use a struct to make passing params during recursion easier
typedef struct
{
    char    *str_p;                 // pointer to string to be searched
    long    str_len;                // length of same
    char    *abbrev_p;              // pointer to search string (abbreviation)
    long    abbrev_len;             // length of same
    double  max_score_per_char;
    int     dot_file;               // boolean: true if str is a dot-file
    int     always_show_dot_files;  // boolean
    int     never_show_dot_files;   // boolean
} matchinfo_t;

// Representation of a range within a search string.
typedef struct {
    int start;
    int length;
} range_t;

// Reverse a string in place. Provided because strrev isn't available
// everywhere.
char* my_strrev(char* s)
{
    char tmp, *p1 = s, *p2 = s + strlen(s);
    while (p1 < --p2) {
        tmp = *p1;
        *p1 = *p2;
        *p2 = tmp;
        p1++;
    }
    return s;
}

// Do a case insensitive find, looking at the appropriate ranges of
// the given source and target strings. Used as a utility function
// by |neo_recursive_match|.
char* strcasestr_in_range(char* source, range_t source_range,
        char* target, range_t target_range)
{
    char* s = source + source_range.start;
    char* t = target + target_range.start;
    char tt = *t++;
    if (!source || !target || !*s || !*t) return NULL;

    do {
        char c;
        do {
            c = *s++;
            if (!c) return NULL;
        } while (c != tt);
    } while (s < source + source_range.start + source_range.length &&
            strncasecmp(s, t, target_range.length-1) != 0);
    return s-1;
}

// Matching scoring algorithm, based on techniques from Quicksilver.
// Looks for matches with a maximal subset of the abbreviation given
// and recursively scores the remainder of the string.
double recursive_match(matchinfo_t* m,
        range_t str_range, range_t abbrev_range)
{
    char* str = m->str_p, *abbrev = m->abbrev_p;
    range_t adjusted_str_range = str_range;
    if (abbrev_range.length == 0) return 0.9;
    if (abbrev_range.length > str_range.length) return 0.0;

    // Look for the start of the abbreviation.
    char c = abbrev[abbrev_range.start];
    char* loc = strchr(str + str_range.start, c);
    if (!loc) loc = strchr(str + str_range.start, toupper(c));
    if (!loc) return 0;
    int skip = (int)(loc - (str + str_range.start));
    adjusted_str_range.length -= skip;
    adjusted_str_range.start += skip;

    for (int i = abbrev_range.length; i>0; i--) {
        //Search for decreasing fragments of the abbreviation.
        range_t curr_abbrev_range = { abbrev_range.start, i };
        range_t curr_str_range = {
            adjusted_str_range.start,
            adjusted_str_range.length - abbrev_range.length + i };
        char* result = strcasestr_in_range(str, curr_str_range, abbrev, curr_abbrev_range);
        if (!result) continue;

        // Search the remainder of the string using the rest of the abbreviation.
        range_t matched_range = { (int)(result - str), curr_abbrev_range.length };
        range_t remaining_str_range = { matched_range.start + matched_range.length,
            str_range.start + str_range.length - (matched_range.start + matched_range.length) };
        range_t remaining_abbrev_range = { abbrev_range.start + i, abbrev_range.length - i };
        double remaining_score = recursive_match(m, remaining_str_range, remaining_abbrev_range);

        if (remaining_score) {
            double score = remaining_str_range.start - str_range.start;
            // Handling for punctuation and capitalization
            if (matched_range.start > str_range.start) {
                if (isspace(str[matched_range.start - 1])) {
                    for (int j = matched_range.start - 2; j >= str_range.start; --j) {
                        score -= isspace(str[j]) ? 1.0 : 0.15;
                    }
                } else if (isupper(str[matched_range.start])) {
                    for (int j = matched_range.start - 1; j >= str_range.start; --j) {
                        score -= isupper(str[j]) ? 1.0 : 0.15;
                    }
                } else if (!isalnum(str[matched_range.start])) {
                    for (int j = matched_range.start - 1; j >= str_range.start; --j) {
                        score -= !isalnum(str[j]) ? 1.0 : 0.15;
                    }
                } else {
                    score -= matched_range.start - str_range.start;
                }
            }
            score += remaining_score * remaining_str_range.length;
            score /= str_range.length;
            return score;
        }
    }
    return 0;
}

// Given a string (full path name) and abbreviation (whatever the user
// typed in), provide a score indicating how highly this file should
// be ranked as a possible match.
double match_score(matchinfo_t *m)
{
    // Handle special dotfile stuff off the top.
    int dotfile = m->str_p[0] == '.' || strstr(m->str_p, "/.");
    if (dotfile) {
        if (m->never_show_dot_files) return 0.0;
        int dotfile_abbrev = strchr(m->abbrev_p, '.');
        if (!dotfile_abbrev && !m->always_show_dot_files) return 0.0;
    }

    // Search the reverse of the input strings, in order to prioritize
    // the end of the file path rather than the beginning. Just take
    // 512 characters in order to avoid any dynamic memory allocation.
    static char r1[512], r2[512];
    strncpy(r1, m->str_p, 512);
    strncpy(r2, m->abbrev_p, 512);
    my_strrev(r1);
    my_strrev(r2);
    m->str_p = r1;
    m->abbrev_p = r2;
    range_t str_range = { 0, m->str_len };
    range_t abbrev_range = { 0, m->abbrev_len };
    return recursive_match(m, str_range, abbrev_range);
}

// Match.new abbrev, string, options = {}
VALUE CommandTMatch_initialize(int argc, VALUE *argv, VALUE self)
{
    // process arguments: 2 mandatory, 1 optional
    VALUE str, abbrev, options;
    if (rb_scan_args(argc, argv, "21", &str, &abbrev, &options) == 2)
        options = Qnil;
    str             = StringValue(str);
    abbrev          = StringValue(abbrev); // already downcased by caller

    // check optional options hash for overrides
    VALUE always_show_dot_files = CommandT_option_from_hash("always_show_dot_files", options);
    VALUE never_show_dot_files = CommandT_option_from_hash("never_show_dot_files", options);

    matchinfo_t m;
    m.str_p                 = RSTRING_PTR(str);
    m.str_len               = RSTRING_LEN(str);
    m.abbrev_p              = RSTRING_PTR(abbrev);
    m.abbrev_len            = RSTRING_LEN(abbrev);
    m.max_score_per_char    = (1.0 / m.str_len + 1.0 / m.abbrev_len) / 2;
    m.dot_file              = 0;
    m.always_show_dot_files = always_show_dot_files == Qtrue;
    m.never_show_dot_files  = never_show_dot_files == Qtrue;

    // calculate score
    double score = 1.0;
    if (m.abbrev_len == 0) // special case for zero-length search string
    {
        // filter out dot files
        if (!m.always_show_dot_files)
        {
            for (long i = 0; i < m.str_len; i++)
            {
                char c = m.str_p[i];
                if (c == '.' && (i == 0 || m.str_p[i - 1] == '/'))
                {
                    score = 0.0;
                    break;
                }
            }
        }
    } else {
        // normal case
        score = match_score(&m);
    }

    // clean-up and final book-keeping
    rb_iv_set(self, "@score", rb_float_new(score));
    rb_iv_set(self, "@str", str);
    return Qnil;
}

VALUE CommandTMatch_matches(VALUE self)
{
    double score = NUM2DBL(rb_iv_get(self, "@score"));
    return score > 0 ? Qtrue : Qfalse;
}

VALUE CommandTMatch_to_s(VALUE self)
{
    return rb_iv_get(self, "@str");
}
