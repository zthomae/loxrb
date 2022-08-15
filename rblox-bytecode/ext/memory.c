#include <stdlib.h>

#include "common.h"
#include "memory.h"
#include "object.h"

void *Memory_reallocate(void *array, size_t old_size, size_t new_size) {
  if (new_size == 0) {
    free(array);
    return NULL;
  }

  void* result = realloc(array, new_size);
  if (result == NULL) exit(1);
  return result;
}

void Memory_free(void *ptr, size_t size) {
  Memory_reallocate(ptr, size, 0);
}

int Memory_grow_capacity(int old_capacity) {
  return old_capacity < 8 ? 8 : old_capacity * 2;
}

void *Memory_grow_array(void *array, size_t item_size, int old_capacity, int new_capacity) {
  size_t old_size = item_size * old_capacity;
  size_t new_size = item_size * new_capacity;
  return Memory_reallocate(array, old_size, new_size);
}

void Memory_free_array(void *array, size_t item_size, int capacity) {
  Memory_reallocate(array, item_size * capacity, 0);
}

void* Memory_allocate(size_t size, size_t count) {
  return Memory_reallocate(NULL, 0, size * count);
}

char* Memory_allocate_chars(size_t count) {
  return (char*)Memory_allocate(sizeof(char), count);
}

void Memory_free_object(Obj* object) {
  switch (object->type) {
    case OBJ_CLOSURE: {
      ObjClosure* closure = (ObjClosure*)object;
      // Don't free the upvalues themselves, because the closure doesn't own them
      Memory_free_array(closure->upvalues, sizeof(ObjUpvalue*), closure->upvalue_count);
      // Don't free function, because the closure doesn't own this either
      Memory_free(object, sizeof(ObjClosure));
      break;
    }
    case OBJ_FUNCTION: {
      ObjFunction* function = (ObjFunction*)object;
      Chunk_free(&function->chunk);
      Memory_free(function, sizeof(ObjFunction));
      // function name is an ObjString, so we leave it for the garbage collector
      break;
    }
    case OBJ_NATIVE:
      Memory_free(object, sizeof(ObjNative));
      break;
    case OBJ_STRING: {
      ObjString* string = (ObjString*)object;
      Memory_free_array(string->chars, sizeof(char), string->length + 1);
      Memory_free(object, sizeof(ObjString));
      break;
    }
    case OBJ_UPVALUE: {
      Memory_free(object, sizeof(ObjUpvalue));
      break;
    }
  }
}
