#include <stdlib.h>

#include "common.h"
#include "memory.h"

static void *memory_reallocate(void *array, size_t old_size, size_t new_size);

int Memory_grow_capacity(int old_capacity) {
  return old_capacity < 8 ? 8 : old_capacity * 2;
}

void *Memory_grow_array(void *array, size_t item_size, int old_capacity, int new_capacity) {
  size_t old_size = item_size * old_capacity;
  size_t new_size = item_size * new_capacity;
  return memory_reallocate(array, old_size, new_size);
}

void Memory_free_array(void *array, size_t item_size, int capacity) {
  memory_reallocate(array, item_size * capacity, 0);
}

static void *memory_reallocate(void *array, size_t old_size, size_t new_size) {
  if (new_size == 0) {
    free(array);
    return NULL;
  }

  void* result = realloc(array, new_size);
  if (result == NULL) exit(1);
  return result;
}
