/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include "commandt.h"

#include <limits.h> /* for UINT_MAX */
#include <stdio.h> /* for perror() */
#include <string.h> /* for strerror() */
#include <sys/errno.h> /* for errno */
#include <time.h> /* for CLOCK_REALTIME, clock_gettime() */
#include <unistd.h> /* for _SC_NPROCESSORS_CONF, sysconf() */

benchmark_t commandt_epoch() {
    struct timespec t;
    benchmark_t result;
    if (clock_gettime(CLOCK_REALTIME, &t) == 0) {
        result.seconds = t.tv_sec;
        result.microseconds = t.tv_nsec / 1000;
    } else {
        perror(strerror(errno));
        result.seconds = 0;
        result.microseconds = 0;
    }
    return result;
}

static unsigned DEFAULT_PROCESSOR_COUNT = 4;

unsigned commandt_processors() {
    long result = sysconf(_SC_NPROCESSORS_CONF);
    if (result == -1) {
        perror(strerror(errno));
        result = DEFAULT_PROCESSOR_COUNT;
    } else if (result <= 0 || result > UINT_MAX) {
        result = DEFAULT_PROCESSOR_COUNT;
    }
    return result;
}
