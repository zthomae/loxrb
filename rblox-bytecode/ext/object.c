#include <stdio.h>
#include <string.h>

#include "memory.h"
#include "object.h"
#include "value.h"
#include "vm.h"

ObjString* object_allocate_string(char* chars, int length);
ObjString* object_allocate_new_string();

ObjString* Object_copy_string(const char* chars, int length) {
  char* heap_chars = Memory_allocate_chars(length + 1);
  memcpy(heap_chars, chars, length);
  heap_chars[length] = '\0';
  return object_allocate_string(heap_chars, length);
}

void Object_print(Value value) {
  switch (Object_type(value)) {
    case OBJ_STRING:
      printf("%s", Object_as_cstring(value));
      break;
  }
}

ObjString* object_allocate_string(char* chars, int length) {
  ObjString* string = object_allocate_new_string();
  string->length = length;
  string->chars = chars;
  return string;
}

Obj* object_allocate_new(size_t size, ObjType type) {
  Obj* object = (Obj*)Memory_reallocate(NULL, 0, size);
  object->type = type;
  return object;
}

ObjString* object_allocate_new_string() {
  return (ObjString*)object_allocate_new(sizeof(ObjString), OBJ_STRING);
}
