#ifndef clox_memory_allocator_h
#define clox_memory_allocator_h

#include "common.h"
#include "object.h"

void* MemoryAllocator_reallocate(void *array, size_t old_size, size_t new_size);
void MemoryAllocator_free(void *ptr, size_t size);
int MemoryAllocator_grow_capacity(int old_capacity);
void* MemoryAllocator_grow_array(void *array, size_t item_size, int old_capacity, int new_capacity);
void MemoryAllocator_free_array(void *array, size_t item_size, int capacity);
void* MemoryAllocator_allocate(size_t size, size_t count);
char* MemoryAllocator_allocate_chars(size_t count);
void MemoryAllocator_free_object(Obj* object);

#endif
