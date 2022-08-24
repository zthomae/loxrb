#ifndef clox_value_array_h
#define clox_value_array_h

#include "value.h"
#include "memory_allocator.h"

typedef struct {
  int capacity;
  int count;
  Value* values;
  MemoryAllocator* memory_allocator;
} ValueArray;

void ValueArray_init(ValueArray* array, MemoryAllocator* memory_allocator);
void ValueArray_write(ValueArray* array, Value value);
void ValueArray_free(ValueArray* array);

#endif
