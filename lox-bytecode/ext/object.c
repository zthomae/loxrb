#include <stdio.h>

#include "object.h"
#include "value.h"

static void object_print_function(ObjFunction* function);

void Object_print(Value value) {
  switch (Object_type(value)) {
    case OBJ_CLOSURE:
      object_print_function(Object_as_closure(value)->function);
      break;
    case OBJ_FUNCTION:
      object_print_function(Object_as_function(value));
      break;
    case OBJ_NATIVE:
      printf("<native fn>");
      break;
    case OBJ_STRING:
      printf("%s", Object_as_cstring(value));
      break;
    case OBJ_UPVALUE:
      printf("upvalue");
      break;
  }
}

static void object_print_function(ObjFunction* function) {
  if (function->name == NULL) {
    printf("<script>");
    return;
  }
  printf("<fn %s>", function->name->chars);
}
