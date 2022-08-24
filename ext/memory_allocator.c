#include <stdlib.h>

#include "common.h"
#include "memory_allocator.h"

#define MIN_INCREASED_CAPACITY 8
#define INCREASED_CAPACITY_SCALING_FACTOR 2

void MemoryAllocator_init(MemoryAllocator* memory_allocator, void* callback_target, MemoryCallbacks callbacks) {
  memory_allocator->bytes_allocated = 0;
  memory_allocator->next_gc = 1024 * 1024;
  memory_allocator->gc_enabled = false;
  memory_allocator->log_gc = false;
  memory_allocator->stress_gc = false;
  memory_allocator->callback_target = callback_target;
  memory_allocator->callbacks = callbacks;
}

void* MemoryAllocator_reallocate(MemoryAllocator* memory_allocator, void* array, size_t old_size, size_t new_size) {
  memory_allocator->bytes_allocated += new_size - old_size;
  if (new_size > old_size) {
    if ((memory_allocator->stress_gc || (memory_allocator->bytes_allocated > memory_allocator->next_gc))) {
      MemoryAllocator_collect_garbage(memory_allocator);
    }
  }

  if (new_size == 0) {
    free(array);
    return NULL;
  }

  void* result = realloc(array, new_size);
  if (result == NULL) exit(1);
  return result;
}

void MemoryAllocator_free(MemoryAllocator* memory_allocator, void* ptr, size_t size) {
  MemoryAllocator_reallocate(memory_allocator, ptr, size, 0);
}

int MemoryAllocator_get_increased_capacity(MemoryAllocator* memory_allocator, int old_capacity) {
  uint8_t min_capacity = MIN_INCREASED_CAPACITY;
  uint8_t scaling_factor = INCREASED_CAPACITY_SCALING_FACTOR;
  return old_capacity < min_capacity ? min_capacity : old_capacity * scaling_factor;
}

void* MemoryAllocator_grow_array(MemoryAllocator* memory_allocator, void* array, size_t item_size, int old_capacity, int new_capacity) {
  size_t old_size = item_size * old_capacity;
  size_t new_size = item_size * new_capacity;
  return MemoryAllocator_reallocate(memory_allocator, array, old_size, new_size);
}

void MemoryAllocator_free_array(MemoryAllocator* memory_allocator, void* array, size_t item_size, int capacity) {
  MemoryAllocator_reallocate(memory_allocator, array, item_size * capacity, 0);
}

void* MemoryAllocator_allocate(MemoryAllocator* memory_allocator, size_t size, size_t count) {
  return MemoryAllocator_reallocate(memory_allocator, NULL, 0, size * count);
}

char* MemoryAllocator_allocate_chars(MemoryAllocator* memory_allocator, size_t count) {
  return (char*)MemoryAllocator_allocate(memory_allocator, sizeof(char), count);
}

void MemoryAllocator_collect_garbage(MemoryAllocator* memory_allocator) {
  (*memory_allocator->callbacks.collect_garbage)(memory_allocator->callback_target);
}
