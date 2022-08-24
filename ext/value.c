#include <stdio.h>
#include <string.h>

#include "object.h"
#include "value.h"

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
