#include <stdlib.h>

#include "common.h"
#include "memory.h"
#include "object.h"
#include "vm.h"

static void memory_free_object(Obj* objecct);

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

char *Memory_allocate_chars(size_t count) {
  return Memory_reallocate(NULL, 0, sizeof(char) * count);
}

void Memory_free_objects(VM* vm) {
  Obj* object = vm->objects;
  while (object != NULL) {
    Obj* next = object->next;
    memory_free_object(object);
    object = next;
  }
}

static void memory_free_object(Obj* object) {
  switch (object->type) {
    case OBJ_STRING: {
      ObjString* string = (ObjString*)object;
      Memory_free_array(string->chars, sizeof(char), string->length + 1);
      Memory_free(object, sizeof(ObjString));
      break;
    }
  }
}