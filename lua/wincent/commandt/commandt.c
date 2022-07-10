/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdio.h> /* for perror() */
#include <string.h> /* for strerror() */
#include <sys/errno.h> /* for errno */
#include <time.h> /* for CLOCK_REALTIME, clock_gettime() */

#include "commandt.h"

benchmark_t commandt_epoch() {
    struct timespec t;
    benchmark_t result;
    if (clock_gettime(CLOCK_REALTIME, &t) == 0) {
        result.seconds =  t.tv_sec;
        result.microseconds = t.tv_nsec / 1000;
    } else {
        perror(strerror(errno));
        result.seconds = 0;
        result.microseconds = 0;
    }
    return result;
}
