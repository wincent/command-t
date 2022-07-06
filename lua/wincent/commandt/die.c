/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

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
