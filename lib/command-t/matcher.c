#include <stdlib.h> /* for qsort() */
#include <string.h> /* for strcmp() */
#include "matcher.h"
#include "ext.h"

// comparison function for use with qsort
int comp(const void *a, const void *b)
{
    VALUE a_val = *(VALUE *)a;
    VALUE b_val = *(VALUE *)b;
    ID score = rb_intern("score");
    ID to_s = rb_intern("to_s");
    double a_score = RFLOAT(rb_funcall(a_val, score, 0))->value;
    double b_score = RFLOAT(rb_funcall(b_val, score, 0))->value;
    if (a_score > b_score)
        return -1; // a scores higher, a should appear sooner
    else if (a_score < b_score)
        return 1;  // b scores higher, a should appear later
    else
    {
        // fall back to alphabetical ordering
        VALUE a_str = rb_funcall(a_val, to_s, 0);
        VALUE b_str = rb_funcall(b_val, to_s, 0);
        char *a_p = RSTRING(a_str)->ptr;
        long a_len = RSTRING(a_str)->len;
        char *b_p = RSTRING(b_str)->ptr;
        long b_len = RSTRING(b_str)->len;
        int order = 0;
        if (a_len > b_len)
        {
            order = strncmp(a_p, b_p, b_len);
            if (order == 0)
                order = 1; // shorter string (b) wins
        }
        else if (a_len < b_len)
        {
            order = strncmp(a_p, b_p, a_len);
            if (order == 0)
                order = -1; // shorter string (a) wins
        }
        else
            order = strncmp(a_p, b_p, a_len);
        return order;
    }
}

VALUE CommandTMatcher_initialize(VALUE self, VALUE scanner)
{
    if (NIL_P(scanner))
        rb_raise(rb_eArgError, "nil scanner");
    rb_iv_set(self, "@scanner", scanner);
    return Qnil;
}

VALUE CommandTMatcher_sorted_matchers_for(VALUE self, VALUE abbrev, VALUE options)
{
    // confirm that we actually got a valid options hash
    if (NIL_P(options) || TYPE(options) != T_HASH)
        rb_raise(rb_eArgError, "options not a hash");

    // get matches in default (alphabetical) ordering
    VALUE matches = CommandTMatcher_matches_for(self, abbrev);

    abbrev = StringValue(abbrev);
    if (RSTRING(abbrev)->len > 0)
        // we have a non-empty search string, so sort by score
        qsort(RARRAY(matches)->ptr, RARRAY(matches)->len, sizeof(VALUE), comp);

    // handle optional limit option
    long limit = 0;
    if (rb_funcall(options, rb_intern("has_key?"), 1, ID2SYM(rb_intern("limit"))) == Qtrue)
        limit = NUM2LONG(rb_hash_aref(options, ID2SYM(rb_intern("limit"))));
    if (limit == 0 || RARRAY(matches)->len < limit)
        limit = RARRAY(matches)->len;

    // will return an array of strings, not an array of Match objects
    for (long i = 0; i < limit; i++)
    {
        VALUE str = rb_funcall(RARRAY(matches)->ptr[i], rb_intern("to_s"), 0);
        RARRAY(matches)->ptr[i] = str;
    }

    // trim off any items beyond the limit
    if (limit < RARRAY(matches)->len)
        (void)rb_funcall(matches, rb_intern("slice!"), 2, LONG2NUM(limit),
            LONG2NUM(RARRAY(matches)->len - limit));
    return matches;
}

VALUE CommandTMatcher_matches_for(VALUE self, VALUE abbrev)
{
    if (NIL_P(abbrev))
        rb_raise(rb_eArgError, "nil abbrev");
    VALUE matches = rb_ary_new();
    VALUE scanner = rb_iv_get(self, "@scanner");
    VALUE paths = rb_funcall(scanner, rb_intern("paths"), 0);
    for (long i = 0, max = RARRAY(paths)->len; i < max; i++)
    {
        VALUE path = RARRAY(paths)->ptr[i];
        VALUE match = rb_funcall(cCommandTMatch, rb_intern("new"), 2, path, abbrev);
        if (rb_funcall(match, rb_intern("matches?"), 0) == Qtrue)
            rb_funcall(matches, rb_intern("push"), 1, match);
    }
    return matches;
}
