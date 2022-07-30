/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef DEBUG_H
#define DEBUG_H

#ifdef DEBUG

#define DEBUG_LOG(format, ...) debugLog(format __VA_OPT__(, ) __VA_ARGS__);

/**
 * Log debug statements to a file, because anything we might log to stdout or
 * stderr is probably going to get obliterated by Neovim before human eyes can
 * see it.
 */
void debugLog(const char *format, ...);

#else

#define DEBUG_LOG(format, ...) /* No logging outside of debug mode. */

#endif

#endif
