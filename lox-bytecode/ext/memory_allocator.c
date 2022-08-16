#include <stdlib.h>

#include "common.h"
#include "memory_allocator.h"
#include "logger.h"

#define DEFAULT_MIN_INCREASED_CAPACITY 8
#define DEFAULT_INCREASED_CAPACITY_SCALING_FACTOR 2

void MemoryAllocator_init(MemoryAllocator* memory_allocator) {
  memory_allocator->min_increased_capacity = DEFAULT_MIN_INCREASED_CAPACITY;
  memory_allocator->increased_capacity_scaling_factor = DEFAULT_INCREASED_CAPACITY_SCALING_FACTOR;
  memory_allocator->log_gc = false;
  memory_allocator->stress_gc = false;
}

void* MemoryAllocator_reallocate(MemoryAllocator* memory_allocator, void* array, size_t old_size, size_t new_size) {
  if (new_size > old_size && memory_allocator->stress_gc) {
    MemoryAllocator_collect_garbage(memory_allocator);
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
  uint8_t min_capacity = memory_allocator->min_increased_capacity;
  uint8_t scaling_factor = memory_allocator->increased_capacity_scaling_factor;
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
  bool print_log_messages = memory_allocator->log_gc;

  if (print_log_messages) {
    Logger_debug("-- start gc --");
  }

  if (print_log_messages) {
    Logger_debug("-- end gc --");
  }
}
