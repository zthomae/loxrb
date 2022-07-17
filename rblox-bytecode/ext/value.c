#include <stdio.h>
#include <string.h>

#include "object.h"
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
      ObjString* a_string = Object_as_string(a);
      ObjString* b_string = Object_as_string(b);
      return a_string->length == b_string->length &&
        memcmp(a_string->chars, b_string->chars, a_string->length) == 0;
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
