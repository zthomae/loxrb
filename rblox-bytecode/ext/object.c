#include <stdio.h>

#include "object.h"
#include "value.h"

void Object_print(Value value) {
  switch (Object_type(value)) {
    case OBJ_STRING:
      printf("%s", Object_as_cstring(value));
      break;
  }
}
