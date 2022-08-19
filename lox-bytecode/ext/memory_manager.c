#include <string.h>

#include "object.h"
#include "table.h"
#include "memory_allocator.h"
#include "memory_manager.h"

static uint32_t memorymanager_hash_string(char* chars, int length);

void MemoryManager_init(MemoryManager* memory_manager) {
  MemoryAllocator_init(&memory_manager->memory_allocator);
  Table_init(&memory_manager->strings, &memory_manager->memory_allocator);
}

ObjString* MemoryManager_copy_string(MemoryManager* memory_manager, char* chars, int length) {
  uint32_t hash = memorymanager_hash_string(chars, length);
  ObjString* interned = Table_find_string(&memory_manager->strings, chars, length, hash);
  if (interned != NULL) {
    return interned;
  }

  char* heap_chars = MemoryAllocator_allocate_chars(&memory_manager->memory_allocator, length + 1);
  memcpy(heap_chars, chars, length);
  heap_chars[length] = '\0';
  ObjString* string = Object_allocate_string(&memory_manager->memory_allocator, heap_chars, length, hash);
  Table_set(&memory_manager->strings, string, Value_make_nil());
  return string;
}

ObjString* MemoryManager_take_string(MemoryManager* memory_manager, char* chars, int length) {
  uint32_t hash = memorymanager_hash_string(chars, length);
  ObjString* interned = Table_find_string(&memory_manager->strings, chars, length, hash);
  if (interned != NULL) {
    MemoryAllocator_free_array(&memory_manager->memory_allocator, chars, sizeof(char), length + 1);
    return interned;
  }

  ObjString* string = Object_allocate_string(&memory_manager->memory_allocator, chars, length, hash);
  Table_set(&memory_manager->strings, string, Value_make_nil());
  return string;
}

void MemoryManager_free(MemoryManager* memory_manager) {
  Obj* object = memory_manager->memory_allocator.objects;
  while (object != NULL) {
    Obj* next = object->next;
    Object_free(&memory_manager->memory_allocator, object);
    object = next;
  }

  Table_free(&memory_manager->strings);
}

static uint32_t memorymanager_hash_string(char* key, int length) {
  uint32_t hash = 2166136261u;
  for (int i = 0; i < length; i++) {
    hash ^= (uint8_t)key[i];
    hash *= 16777619;
  }
  return hash;
}
