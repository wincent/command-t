// Copyright 2021-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <stdio.h> /* for fprintf() */
#include <stdlib.h> /* for abort() */
#include <string.h> /* for strerror() */

void die(char *reason, int error) {
    if (reason) {
        fprintf(stderr, "die(): %s - %s\n", reason, strerror(error));
    } else {
        fprintf(stderr, "die(): %s\n", strerror(error));
    }
    abort();
}
