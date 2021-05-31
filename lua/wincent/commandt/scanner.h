// Copyright 2021-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#ifndef SCANNER_H
#define SCANNER_H

typedef struct {
    const char **candidates;
    long count;

    /**
     * Counter that increments any time the candidates change.
     */
    unsigned version; // TODO: figure out whether i need this
} scanner_t;

scanner_t *scanner_new();
void scanner_free(scanner_t *scanner);

#endif
