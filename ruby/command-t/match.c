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

double recursive_match(matchinfo_t *m, long str_idx, long abbrev_idx)
{
    double my_score = 0;        // cumulatively calculate match score
    double seen_score = 0;      // remember best score seen via recursion
    int dot_file_match = 0;     // true if abbrev matches a dot-file
    int dot_search = 0;         // true if searching for a dot

    for (long i = abbrev_idx; i < m->abbrev_len; i++)
    {
        char c = m->abbrev_p[i];
        if (c >= 'A' && c <= 'Z')
            c += 'a' - 'A'; // add 32 to downcase
        else if (c == '.')
            dot_search = 1;
        for (long j = str_idx; j < m->str_len; j++)
        {
            char d = m->str_p[j];
            if (d == '.')
            {
                if (j == 0 || m->str_p[j - 1] == '/')
                {
                    m->dot_file = 1;        // this is a dot-file
                    if (dot_search)         // and we are searching for a dot
                        dot_file_match = 1; // so this must be a match
                }
            }
            else if (d >= 'A' && d <= 'Z')
                d += 'a' - 'A'; // add 32 to downcase
            if (c == d)
            {
                dot_search = 0;
                my_score = 0; // calculate score

                if (j + 1 < m->str_len)
                {
                    // bump cursor one char to the right and
                    // use recursion to try and find a better match
                    double score = recursive_match(m, i, j + 1);
                    if (score > seen_score)
                        seen_score = score;
                }
                break;
            }
        }
    }

    if (m->dot_file)
    {
        if (m->never_show_dot_files ||
            (!dot_file_match && !m->always_show_dot_files))
            return 0;
    }
    return (my_score > seen_score) ? my_score : seen_score;
}

double best_match(matchinfo_t *m)
{
    // pre-calculations
    m->max_score_per_char = 1.0 / m->abbrev_len;
    m->dot_file = 0;

    // special case for zero-length search string: filter out dot files
    if (m->abbrev_len == 0 && !m->always_show_dot_files)
    {
        for (long i = 0; i < m->str_len; i++)
        {
            char c = m->str_p[i];
            if (c == '.' && (i == 0 || m->str_p[i - 1] == '/'))
            {
                m->dot_file = 1;
                break;
            }
        }
    }
    return recursive_match(m, 0, 0);
}

// Match.new abbrev, string, options = {}
VALUE CommandTMatch_initialize(int argc, VALUE *argv, VALUE self)
{
    // process arguments: 2 mandatory, 1 optional
    VALUE str, abbrev, options;
    if (rb_scan_args(argc, argv, "21", &str, &abbrev, &options) == 2)
        options = Qnil;
    str                     = StringValue(str);
    char *str_p             = RSTRING_PTR(str);
    long str_len            = RSTRING_LEN(str);
    abbrev                  = StringValue(abbrev);
    char *abbrev_p          = RSTRING_PTR(abbrev);
    long abbrev_len         = RSTRING_LEN(abbrev);

    // check optional options hash for overrides
    VALUE always_show_dot_files = CommandT_option_from_hash("always_show_dot_files", options);
    VALUE never_show_dot_files = CommandT_option_from_hash("never_show_dot_files", options);

    long cursor             = 0;
    int dot_file            = 0; // true if str is a dot-file
    int dot_file_match      = 0; // true if abbrev matches a dot-file
    int dot_search          = 0; // true if searching for a dot

    rb_iv_set(self, "@str", str);
    VALUE offsets = rb_ary_new();

    // special case for zero-length search string: filter out dot-files
    if (abbrev_len == 0 && always_show_dot_files != Qtrue)
    {
        for (long i = 0; i < str_len; i++)
        {
            char c = str_p[i];
            if (c == '.')
            {
                if (i == 0 || str_p[i - 1] == '/')
                {
                    dot_file = 1;
                    break;
                }
            }
        }
    }

    for (long i = 0; i < abbrev_len; i++)
    {
        char c = abbrev_p[i];
        if (c >= 'A' && c <= 'Z')
            c += 'a' - 'A'; // add 32 to make lowercase
        else if (c == '.')
            dot_search = 1;

        VALUE found = Qfalse;
        for (long j = cursor; j < str_len; j++, cursor++)
        {
            char d = str_p[j];
            if (d == '.')
            {
                if (j == 0 || str_p[j - 1] == '/')
                {
                    dot_file = 1;           // this is a dot-file
                    if (dot_search)         // and we are searching for a dot
                        dot_file_match = 1; // so this must be a match
                }
            }
            else if (d >= 'A' && d <= 'Z')
                d += 'a' - 'A'; // add 32 to make lowercase
            if (c == d)
            {
                dot_search = 0;
                rb_ary_push(offsets, LONG2FIX(cursor));
                cursor++;
                found = Qtrue;
                break;
            }
        }

        if (found == Qfalse)
        {
            offsets = Qnil;
            break;
        }
    }

    if (dot_file)
    {
        if (never_show_dot_files == Qtrue ||
            (!dot_file_match && always_show_dot_files != Qtrue))
            offsets = Qnil;
    }
    rb_iv_set(self, "@offsets", offsets);
    return Qnil;
}

VALUE CommandTMatch_matches(VALUE self)
{
    VALUE offsets = rb_iv_get(self, "@offsets");
    return NIL_P(offsets) ? Qfalse : Qtrue;
}

// Return a normalized score ranging from 0.0 to 1.0 indicating the
// relevance of the match. The algorithm is specialized to provide
// intuitive scores specifically for filesystem paths.
//
// 0.0 means the search string didn't match at all.
//
// 1.0 means the search string is a perfect (letter-for-letter) match.
//
// Scores will tend closer to 1.0 as:
//
//   - the number of matched characters increases
//   - matched characters appear closer to previously matched characters
//   - matched characters appear immediately after special "boundary"
//     characters such as "/", "_", "-", "." and " "
//   - matched characters are uppercase letters immediately after
//     lowercase letters of numbers
//   - matched characters are lowercase letters immediately after
//     numbers
VALUE CommandTMatch_score(VALUE self)
{
    // return previously calculated score if available
    VALUE score = rb_iv_get(self, "@score");
    if (!NIL_P(score))
        return score;

    // nil or empty offsets array means a score of 0.0
    VALUE offsets = rb_iv_get(self, "@offsets");
    if (NIL_P(offsets) || RARRAY_LEN(offsets) == 0)
    {
        score = rb_float_new(0.0);
        rb_iv_set(self, "@score", score);
        return score;
    }

    // if search string is equal to actual string score is 1.0
    VALUE str = rb_iv_get(self, "@str");
    if (RARRAY_LEN(offsets) == RSTRING_LEN(str))
    {
        score = rb_float_new(1.0);
        rb_iv_set(self, "@score", score);
        return score;
    }

    double score_d = 0.0;
    double max_score_per_char = 1.0 / RARRAY_LEN(offsets);
    for (long i = 0, max = RARRAY_LEN(offsets); i < max; i++)
    {
        double score_for_char = max_score_per_char;
        long offset = FIX2LONG(RARRAY_PTR(offsets)[i]);
        if (offset > 0)
        {
            double factor   = 0.0;
            char curr       = RSTRING_PTR(str)[offset];
            char last       = RSTRING_PTR(str)[offset - 1];

            // look at previous character to see if it is "special"
            // NOTE: possible improvements here:
            // - number after another number should be 1.0, not 0.8
            // - need to think about sequences like "9-"
            if (last == '/')
                factor = 0.9;
            else if (last == '-' ||
                     last == '_' ||
                     last == ' ' ||
                     (last >= '0' && last <= '9'))
                factor = 0.8;
            else if (last == '.')
                factor = 0.7;
            else if (last >= 'a' && last <= 'z' &&
                     curr >= 'A' && curr <= 'Z')
                factor = 0.8;
            else
            {
                // if no "special" chars behind char, factor diminishes
                // as distance from last matched char increases
                if (i > 1)
                {
                    long distance = offset - FIX2LONG(RARRAY_PTR(offsets)[i - 1]);
                    factor = 1.0 / distance;
                }
                else
                    factor = 1.0 / (offset + 1);
            }
            score_for_char *= factor;
        }
        score_d += score_for_char;
    }
    score = rb_float_new(score_d);
    rb_iv_set(self, "@score", score);
    return score;
}

VALUE CommandTMatch_to_s(VALUE self)
{
    return rb_iv_get(self, "@str");
}
