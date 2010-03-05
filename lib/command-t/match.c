#include "match.h"

VALUE CommandTMatch_initialize(VALUE self, VALUE str, VALUE abbrev)
{
    abbrev          = StringValue(abbrev);
    char *abbrev_p  = RSTRING_PTR(abbrev);
    long abbrev_len = RSTRING_LEN(abbrev);
    str             = StringValue(str);
    char *str_p     = RSTRING_PTR(str);
    long str_len    = RSTRING_LEN(str);
    long cursor     = 0;

    rb_iv_set(self, "@str", str);
    VALUE offsets = rb_ary_new();

    for (long i = 0; i < abbrev_len; i++)
    {
        char c = abbrev_p[i];
        if ((c >= 'A') && (c <= 'Z'))
            c += ('a' - 'A'); // add 32 to make lowercase

        VALUE found = Qfalse;
        for (long j = cursor; j < str_len; j++, cursor++)
        {
            char d = str_p[j];
            if ((d >= 'A') && (d <= 'Z'))
                d += ('a' - 'A'); // add 32 to make lowercase
            if (c == d)
            {
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
    if (NIL_P(offsets) || (RARRAY(offsets)->len == 0))
    {
        score = rb_float_new(0.0);
        rb_iv_set(self, "@score", score);
        return score;
    }

    // if search string is equal to actual string score is 1.0
    VALUE str = rb_iv_get(self, "@str");
    if (RARRAY(offsets)->len == RSTRING(str)->len)
    {
        score = rb_float_new(1.0);
        rb_iv_set(self, "@score", score);
        return score;
    }

    double score_d = 0.0;
    double max_score_per_char = 1.0 / RARRAY(offsets)->len;
    for (long i = 0, max = RARRAY(offsets)->len; i < max; i++)
    {
        double score_for_char = max_score_per_char;
        long offset = FIX2LONG(RARRAY(offsets)->ptr[i]);
        if (offset > 0)
        {
            double factor   = 0.0;
            char curr       = RSTRING(str)->ptr[offset];
            char last       = RSTRING(str)->ptr[offset - 1];

            // look at previous character to see if it is "special"
            // NOTE: possible improvements here:
            // - number after another number should be 1.0, not 0.8
            // - need to think about sequences like "9-"
            if (last == '/')
                factor = 0.9;
            else if ((last == '-') ||
                     (last == '_') ||
                     (last == ' ') ||
                     ((last >= '0') && (last <= '9')))
                factor = 0.8;
            else if (last == '.')
                factor = 0.7;
            else if (((last >= 'a') && (last <= 'z')) &&
                     ((curr >= 'A') && (curr <= 'Z')))
                factor = 0.8;
            else
            {
                // if no "special" chars behind char, factor diminishes
                // as distance from last matched char increases
                if (i > 1)
                {
                    long distance = offset - FIX2LONG(RARRAY(offsets)->ptr[i - 1]);
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
