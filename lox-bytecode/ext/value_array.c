#include "common.h"
#include "value.h"
#include "value_array.h"
#include "memory_allocator.h"

void ValueArray_init(ValueArray* array, MemoryAllocator* memory_allocator) {
  array->values = NULL;
  array->capacity = 0;
  array->count = 0;
  array->memory_allocator = memory_allocator;
}

void ValueArray_write(ValueArray* array, Value value) {
  if (array->capacity < array->count + 1) {
    int old_capacity = array->capacity;
    array->capacity = MemoryAllocator_get_increased_capacity(array->memory_allocator, old_capacity);
    array->values = (Value*) MemoryAllocator_grow_array(array->memory_allocator, array->values, sizeof(Value), old_capacity, array->capacity);
  }

  array->values[array->count] = value;
  array->count++;
}

void ValueArray_free(ValueArray* array) {
  MemoryAllocator_free_array(array->memory_allocator, array->values, sizeof(Value), array->capacity);
  ValueArray_init(array, array->memory_allocator);
}
