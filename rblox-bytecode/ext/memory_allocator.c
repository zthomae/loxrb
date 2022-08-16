#include <stdlib.h>

#include "common.h"
#include "memory_allocator.h"

void MemoryAllocator_init(MemoryAllocator* memory_allocator) {
  memory_allocator->log_gc = false;
  memory_allocator->stress_gc = false;
}

void *MemoryAllocator_reallocate(void *array, size_t old_size, size_t new_size) {
  if (new_size == 0) {
    free(array);
    return NULL;
  }

  void* result = realloc(array, new_size);
  if (result == NULL) exit(1);
  return result;
}

void MemoryAllocator_free(void *ptr, size_t size) {
  MemoryAllocator_reallocate(ptr, size, 0);
}

int MemoryAllocator_grow_capacity(int old_capacity) {
  return old_capacity < 8 ? 8 : old_capacity * 2;
}

void *MemoryAllocator_grow_array(void *array, size_t item_size, int old_capacity, int new_capacity) {
  size_t old_size = item_size * old_capacity;
  size_t new_size = item_size * new_capacity;
  return MemoryAllocator_reallocate(array, old_size, new_size);
}

void MemoryAllocator_free_array(void *array, size_t item_size, int capacity) {
  MemoryAllocator_reallocate(array, item_size * capacity, 0);
}

void* MemoryAllocator_allocate(size_t size, size_t count) {
  return MemoryAllocator_reallocate(NULL, 0, size * count);
}

char* MemoryAllocator_allocate_chars(size_t count) {
  return (char*)MemoryAllocator_allocate(sizeof(char), count);
}
