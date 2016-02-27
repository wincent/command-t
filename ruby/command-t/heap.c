// Copyright 2016-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <stdlib.h>

#include "heap.h"

#define HEAP_PARENT(index) ((index - 1) / 2)
#define HEAP_LEFT(index) (2 * index + 1)
#define HEAP_RIGHT(index) (2 * index + 2)

/**
 * Returns a new heap, or NULL on failure.
 */
heap_t *heap_new(int capacity, heap_compare_entries comparator) {
    heap_t *heap = malloc(sizeof(heap_t));
    if (!heap) {
        return NULL;
    }
    heap->comparator = comparator;
    heap->count = 0;
    heap->capacity = capacity;

    // Overallocate by one slot.
    heap->entries = malloc((capacity + 1) * sizeof(void *));
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
int heap_compare(heap_t *heap, int a_idx, int b_idx) {
    void *a = heap->entries[a_idx];
    void *b = heap->entries[b_idx];
    return heap->comparator(a, b);
}

/**
 * @internal
 *
 * Returns 1 if the heap property holds (ie. parent < child).
 */
int heap_property(heap_t *heap, int parent_idx, int child_idx) {
    return heap_compare(heap, parent_idx, child_idx) == -1;
}

/**
 * @internal
 *
 * Swaps the values at indexes `a` and `b` within `heap`.
 */
void heap_swap(heap_t *heap, int a, int b) {
    void *tmp = heap->entries[a];
    heap->entries[a] = heap->entries[b];
    heap->entries[b] = tmp;
}

/**
 * Inserts `value` into `heap`.
 */
void heap_insert(heap_t *heap, void *value) {
    // Insert into first empty slot.
    int idx = heap->count;
    heap->entries[idx] = value;
    heap->count++;

    // Bubble upwards until heap property is restored.
    int parent_idx = HEAP_PARENT(idx);
    while (idx && !heap_property(heap, parent_idx, idx)) {
        heap_swap(heap, idx, parent_idx);
        idx = parent_idx;
        parent_idx = HEAP_PARENT(idx);
    }

    // If at capacity, drop largest value.
    if (heap->count > heap->capacity) {
        heap->count = heap->capacity;
    }
}

/**
 * @internal
 *
 * Restores the heap property starting at `idx`.
 */
void heap_heapify(heap_t *heap, int idx) {
    int left_idx = HEAP_LEFT(idx);
    int right_idx = HEAP_RIGHT(idx);
    int smallest_idx =
        right_idx < heap->count ?

        // Right (and therefore left) child exists.
        (heap_compare(heap, left_idx, right_idx == -1) ? left_idx : right_idx) :

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
 * Bulk insert in O(n) time.
 */
void heap_bulk_insert(heap_t *heap, int count, void **values) {
    // Insert without concern for heap property.
    int i;
    for (i = 0; i < count; i++) {
        heap->entries[heap->count] = values[i];
        heap->count++;
        if (heap->count > heap->capacity) {
            heap->count = heap->capacity;
        }
    }

    // Re-establish heap property.
    for (i = (heap->count - 1) / 2; i >= 0; i--) {
        heap_heapify(heap, i);
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
