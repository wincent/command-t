// Copyright 2021-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#ifndef COMMANDT_H
#define COMMANDT_H

/**
 *  Represents a single "haystack" (ie. a string to be searched for the needle).
 */
typedef struct {
    const char *candidate;
    // TODO: probably don't need `long` here! PATH_MAX is small
    // but most string methods return size_t (which is effectively long, at least)
    long length;

    /**
     * Original index in the scanner's candidates array, so that we can return
     * the matching result to Lua without having to copy an entire string.
     */
    long index; // TODO: decide if this is worth doing it; copying may not be too bad because we expect limit to generally be in effect (and low).

    long bitmask;
    float score;
} haystack_t;

#endif
