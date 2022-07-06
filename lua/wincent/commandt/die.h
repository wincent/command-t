/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef DIE_H
#define DIE_H

/**
 * Prints the `reason` message (if supplied; otherwise it uses a default
 * message) and `error` details as obtained from `strerror()`, then aborts the
 * program.
 */
void die(char *reason, int error);

#endif
