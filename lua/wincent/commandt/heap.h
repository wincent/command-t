// Copyright 2016-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

/**
 * A fixed size min-heap implementation.
 */

typedef int (*heap_compare_entries)(const void *a, const void *b);

typedef struct {
    long count;
    long capacity;
    void **entries;
    heap_compare_entries comparator;
} heap_t;

#define HEAP_PEEK(heap) (heap->entries[0])

heap_t *heap_new(long capacity, heap_compare_entries comparator);
void heap_free(heap_t *heap);
void heap_insert(heap_t *heap, void *value);
void *heap_extract(heap_t *heap);
