#include <stdio.h>
#include <string.h>

#include "object.h"
#include "memory_allocator.h"
#include "value.h"

void ValueArray_init(ValueArray* array, MemoryAllocator* memory_allocator) {
  array->values = NULL;
  array->capacity = 0;
  array->count = 0;
  array->memory_allocator = memory_allocator;
}

void ValueArray_write(ValueArray* array, Value value) {
  if (array->capacity < array->count + 1) {
    int old_capacity = array->capacity;
    array->capacity = MemoryAllocator_grow_capacity(old_capacity);
    array->values = (Value*) MemoryAllocator_grow_array(array->values, sizeof(Value), old_capacity, array->capacity);
  }

  array->values[array->count] = value;
  array->count++;
}

void ValueArray_free(ValueArray* array) {
  MemoryAllocator_free_array(array->values, sizeof(Value), array->capacity);
  ValueArray_init(array, array->memory_allocator);
}

bool Value_equals(Value a, Value b) {
  if (a.type != b.type) {
    return false;
  }
  switch (a.type) {
    case VAL_BOOL:
      return Value_as_boolean(a) == Value_as_boolean(b);
    case VAL_NIL:
      return true;
    case VAL_NUMBER:
      return Value_as_number(a) == Value_as_number(b);
    case VAL_OBJ: {
      return Value_as_obj(a) == Value_as_obj(b);
    }
    default:
      return false;
  }
}

void Value_print(Value value) {
  switch (value.type) {
    case VAL_BOOL:
      printf(Value_as_boolean(value) ? "true" : "false");
      break;
    case VAL_NIL:
      printf("nil");
      break;
    case VAL_NUMBER:
      printf("%g", Value_as_number(value));
      break;
    case VAL_OBJ:
      Object_print(value);
      break;
  }
}
