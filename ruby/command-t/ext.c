// Copyright 2010-2014 Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include "matcher.h"
#include "watchman.h"

VALUE mCommandT              = 0; // module CommandT
VALUE cCommandTMatcher       = 0; // class CommandT::Matcher
VALUE mCommandTWatchman      = 0; // module CommandT::Watchman
VALUE mCommandTWatchmanUtils = 0; // module CommandT::Watchman::Utils

VALUE CommandT_option_from_hash(const char *option, VALUE hash)
{
    VALUE key;
    if (NIL_P(hash))
        return Qnil;
    key = ID2SYM(rb_intern(option));
    if (rb_funcall(hash, rb_intern("has_key?"), 1, key) == Qtrue)
        return rb_hash_aref(hash, key);
    else
        return Qnil;
}

void Init_ext()
{
    // module CommandT
    mCommandT = rb_define_module("CommandT");

    // class CommandT::Matcher
    cCommandTMatcher = rb_define_class_under(mCommandT, "Matcher", rb_cObject);
    rb_define_method(cCommandTMatcher, "initialize", CommandTMatcher_initialize, -1);
    rb_define_method(cCommandTMatcher, "sorted_matches_for", CommandTMatcher_sorted_matches_for, -1);

    // module CommandT::Watchman::Utils
    mCommandTWatchman = rb_define_module_under(mCommandT, "Watchman");
    mCommandTWatchmanUtils = rb_define_module_under(mCommandTWatchman, "Utils");
    rb_define_singleton_method(mCommandTWatchmanUtils, "load", CommandTWatchmanUtils_load, 1);
    rb_define_singleton_method(mCommandTWatchmanUtils, "dump", CommandTWatchmanUtils_dump, 1);
    rb_define_singleton_method(mCommandTWatchmanUtils, "query", CommandTWatchmanUtils_query, 2);
}
