#ifndef clox_memory_h
#define clox_memory_h

#include "common.h"

void *Memory_reallocate(void *array, size_t old_size, size_t new_size);
int Memory_grow_capacity(int old_capacity);
void *Memory_grow_array(void *array, size_t item_size, int old_capacity, int new_capacity);
void Memory_free_array(void *array, size_t item_size, int capacity);
char *Memory_allocate_chars(size_t count);

#endif
