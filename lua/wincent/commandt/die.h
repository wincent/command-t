// Copyright 2021-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

/**
 * Prints the `reason` message (if supplied; otherwise it uses a default
 * message) and `error` details as obtained from `strerror()`, then aborts the
 * program.
 */
void die(char *reason, int error);
