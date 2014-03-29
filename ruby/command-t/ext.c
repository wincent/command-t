// Copyright 2010-2014 Wincent Colaiuta. All rights reserved.
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
