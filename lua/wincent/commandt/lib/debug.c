/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifdef DEBUG

#include <stdarg.h> /* for va_start() etc */
#include <stdio.h> /* for FILE, fopen() */

void debugLog(const char *format, ...) {
    FILE *file = fopen("commandt-debug.log", "a");
    if (file != NULL) {
        va_list args;
        va_start(args, format);
        vfprintf(file, format, args);
        va_end(args);
        fclose(file);
    }
}

#endif
