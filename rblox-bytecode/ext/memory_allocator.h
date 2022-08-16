#ifndef clox_memory_allocator_h
#define clox_memory_allocator_h

#include "common.h"

typedef struct {
  bool log_gc;
  bool stress_gc;
} MemoryAllocator;

void MemoryAllocator_init(MemoryAllocator* memory_allocator);
void* MemoryAllocator_reallocate(MemoryAllocator* memory_allocator, void* array, size_t old_size, size_t new_size);
void MemoryAllocator_free(MemoryAllocator* memory_allocator, void* ptr, size_t size);
int MemoryAllocator_get_increased_capacity(int old_capacity);
void* MemoryAllocator_grow_array(MemoryAllocator* memory_allocator, void* array, size_t item_size, int old_capacity, int new_capacity);
void MemoryAllocator_free_array(MemoryAllocator* memory_allocator, void* array, size_t item_size, int capacity);
void* MemoryAllocator_allocate(MemoryAllocator* memory_allocator, size_t size, size_t count);
char* MemoryAllocator_allocate_chars(MemoryAllocator* memory_allocator, size_t count);

#endif
