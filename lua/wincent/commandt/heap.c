// Copyright 2016-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <stdlib.h> /* for free(), malloc(), NULL */

#include "heap.h"

#define HEAP_PARENT(index) ((index - 1) / 2)
#define HEAP_LEFT(index) (2 * index + 1)
#define HEAP_RIGHT(index) (2 * index + 2)

/**
 * Returns a new heap, or NULL on failure.
 */
heap_t *heap_new(long capacity, heap_compare_entries comparator) {
    heap_t *heap = malloc(sizeof(heap_t));
    if (!heap) {
        return NULL;
    }
    heap->capacity = capacity;
    heap->comparator = comparator;
    heap->count = 0;

    heap->entries = malloc(capacity * sizeof(void *));
    if (!heap->entries) {
        free(heap);
        return NULL;
    }
    return heap;
}

/**
 * Frees a previously created heap.
 */
void heap_free(heap_t *heap) {
    free(heap->entries);
    free(heap);
}

/**
 * @internal
 *
 * Compare values at indices `a_idx` and `b_idx` using the heap's comparator
 * function.
 */
int heap_compare(heap_t *heap, long a_idx, long b_idx) {
    const void *a = heap->entries[a_idx];
    const void *b = heap->entries[b_idx];
    return heap->comparator(a, b);
}

/**
 * @internal
 *
 * Returns 1 if the heap property holds (ie. parent < child).
 */
int heap_property(heap_t *heap, long parent_idx, long child_idx) {
    return heap_compare(heap, parent_idx, child_idx) > 0;
}

/**
 * @internal
 *
 * Swaps the values at indexes `a` and `b` within `heap`.
 */
void heap_swap(heap_t *heap, long a, long b) {
    void *tmp = heap->entries[a];
    heap->entries[a] = heap->entries[b];
    heap->entries[b] = tmp;
}

/**
 * Inserts `value` into `heap`.
 */
void heap_insert(heap_t *heap, void *value) {
    long idx, parent_idx;

    // If at capacity, ignore.
    if (heap->count == heap->capacity) {
        return;
    }

    // Insert into first empty slot.
    idx = heap->count;
    heap->entries[idx] = value;
    heap->count++;

    // Bubble upwards until heap property is restored.
    parent_idx = HEAP_PARENT(idx);
    while (idx && !heap_property(heap, parent_idx, idx)) {
        heap_swap(heap, idx, parent_idx);
        idx = parent_idx;
        parent_idx = HEAP_PARENT(idx);
    }
}

/**
 * @internal
 *
 * Restores the heap property starting at `idx`.
 */
void heap_heapify(heap_t *heap, long idx) {
    long left_idx = HEAP_LEFT(idx);
    long right_idx = HEAP_RIGHT(idx);
    long smallest_idx =
        right_idx < heap->count ?

        // Right (and therefore left) child exists.
        (heap_compare(heap, left_idx, right_idx) > 0 ? left_idx : right_idx) :

        left_idx < heap->count ?

        // Only left child exists.
        left_idx :

        // No children exist.
        idx;

    if (
        smallest_idx != idx &&
        !heap_property(heap, idx, smallest_idx)
    ) {
        // Swap with smallest_idx child.
        heap_swap(heap, idx, smallest_idx);
        heap_heapify(heap, smallest_idx);
    }
}

/**
 * Extracts the minimum value from `heap`.
 */
void *heap_extract(heap_t *heap) {
    void *extracted = NULL;
    if (heap->count) {
        // Grab root value.
        extracted = heap->entries[0];

        // Move last item to root.
        heap->entries[0] = heap->entries[heap->count - 1];
        heap->count--;

        // Restore heap property.
        heap_heapify(heap, 0);
    }
    return extracted;
}
