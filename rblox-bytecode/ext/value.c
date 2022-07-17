#include <stdio.h>

#include "memory.h"
#include "value.h"

void ValueArray_init(ValueArray* array) {
  array->values = NULL;
  array->capacity = 0;
  array->count = 0;
}

void ValueArray_write(ValueArray* array, Value value) {
  if (array->capacity < array->count + 1) {
    int old_capacity = array->capacity;
    array->capacity = Memory_grow_capacity(old_capacity);
    array->values = (Value*) Memory_grow_array(array->values, sizeof(Value), old_capacity, array->capacity);
  }

  array->values[array->count] = value;
  array->count++;
}

void ValueArray_free(ValueArray* array) {
  Memory_free_array(array->values, sizeof(Value), array->capacity);
  ValueArray_init(array);
}

void Value_print(Value value) {
  printf("%g", Value_as_number(value));
}
