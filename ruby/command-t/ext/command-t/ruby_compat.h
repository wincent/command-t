/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-LicenseIdentifier: BSD-2-Clause
 */

#include <ruby.h>

// for compatibility with older versions of Ruby which don't declare RSTRING_PTR
#ifndef RSTRING_PTR
#define RSTRING_PTR(s) (RSTRING(s)->ptr)
#endif

// for compatibility with older versions of Ruby which don't declare RSTRING_LEN
#ifndef RSTRING_LEN
#define RSTRING_LEN(s) (RSTRING(s)->len)
#endif

// for compatibility with older versions of Ruby which don't declare RARRAY_PTR
#ifndef RARRAY_PTR
#define RARRAY_PTR(a) (RARRAY(a)->ptr)
#endif

// for compatibility with older versions of Ruby which don't declare RARRAY_LEN
#ifndef RARRAY_LEN
#define RARRAY_LEN(a) (RARRAY(a)->len)
#endif

// for compatibility with older versions of Ruby which don't declare RFLOAT_VALUE
#ifndef RFLOAT_VALUE
#define RFLOAT_VALUE(f) (RFLOAT(f)->value)
#endif
