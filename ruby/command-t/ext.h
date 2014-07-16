// Copyright 2010-2014 Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <ruby.h>

extern VALUE mCommandT;              // module CommandT
extern VALUE cCommandTMatcher;       // class CommandT::Matcher
extern VALUE mCommandTWatchman;      // module CommandT::Watchman
extern VALUE mCommandTWatchmanUtils; // module CommandT::Watchman::Utils

// Encapsulates common pattern of checking for an option in an optional
// options hash. The hash itself may be nil, but an exception will be
// raised if it is not nil and not a hash.
VALUE CommandT_option_from_hash(const char *option, VALUE hash);

// Debugging macro.
#define ruby_inspect(obj) rb_funcall(rb_mKernel, rb_intern("p"), 1, obj)
