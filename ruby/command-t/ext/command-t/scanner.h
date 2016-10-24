// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include "match.h"

extern VALUE CommandTPaths_from_array(VALUE, VALUE);
extern VALUE CommandTPaths_from_fd(VALUE, VALUE, VALUE, VALUE);
extern VALUE CommandTPaths_to_a(VALUE);

extern matches_t *paths_get_matches(VALUE);
extern VALUE matches_to_a(matches_t *);
