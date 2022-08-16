#include <string.h>

#include "object.h"
#include "table.h"
#include "memory_allocator.h"
#include "memory_manager.h"

Obj* memorymanager_allocate_new(MemoryManager* memory_manager, size_t size, ObjType type);
static uint32_t memorymanager_hash_string(char* chars, int length);

void MemoryManager_init(MemoryManager* memory_manager) {
  memory_manager->objects = NULL;
  MemoryAllocator_init(&memory_manager->memory_allocator);
  Table_init(&memory_manager->strings);
}

ObjString* MemoryManager_allocate_string(MemoryManager* memory_manager, char* chars, int length, uint32_t hash) {
  ObjString* string = MemoryManager_allocate_new_string(memory_manager);
  string->length = length;
  string->chars = chars;
  string->hash = hash;
  Table_set(&memory_manager->strings, string, Value_make_nil());
  return string;
}

ObjString* MemoryManager_allocate_new_string(MemoryManager* memory_manager) {
  return (ObjString*)memorymanager_allocate_new(memory_manager, sizeof(ObjString), OBJ_STRING);
}

ObjUpvalue* MemoryManager_allocate_new_upvalue(MemoryManager* memory_manager, Value* slot) {
  ObjUpvalue* upvalue = (ObjUpvalue*)memorymanager_allocate_new(memory_manager, sizeof(ObjUpvalue), OBJ_UPVALUE);
  upvalue->location = slot;
  upvalue->closed = Value_make_nil();
  upvalue->next = NULL;
  return upvalue;
}

ObjFunction* MemoryManager_allocate_new_function(MemoryManager* memory_manager) {
  return (ObjFunction*)memorymanager_allocate_new(memory_manager, sizeof(ObjFunction), OBJ_FUNCTION);
}

ObjNative* MemoryManager_allocate_new_native(MemoryManager* memory_manager, NativeFn function) {
  ObjNative* native = (ObjNative*)memorymanager_allocate_new(memory_manager, sizeof(ObjNative), OBJ_NATIVE);
  native->function = function;
  return native;
}

ObjClosure* MemoryManager_allocate_new_closure(MemoryManager* memory_manager, ObjFunction* function) {
  ObjUpvalue** upvalues = MemoryAllocator_allocate(sizeof(ObjUpvalue*), function->upvalue_count);
  for (int i = 0; i < function->upvalue_count; i++) {
    upvalues[i] = NULL;
  }
  ObjClosure* closure = (ObjClosure*)memorymanager_allocate_new(memory_manager, sizeof(ObjClosure), OBJ_CLOSURE);
  closure->function = function;
  closure->upvalues = upvalues;
  closure->upvalue_count = function->upvalue_count;
  return closure;
}

ObjString* MemoryManager_copy_string(MemoryManager* memory_manager, char* chars, int length) {
  uint32_t hash = memorymanager_hash_string(chars, length);
  ObjString* interned = Table_find_string(&memory_manager->strings, chars, length, hash);
  if (interned != NULL) {
    return interned;
  }

  char* heap_chars = MemoryAllocator_allocate_chars(length + 1);
  memcpy(heap_chars, chars, length);
  heap_chars[length] = '\0';
  return MemoryManager_allocate_string(memory_manager, heap_chars, length, hash);
}

ObjString* MemoryManager_take_string(MemoryManager* memory_manager, char* chars, int length) {
  uint32_t hash = memorymanager_hash_string(chars, length);
  ObjString* interned = Table_find_string(&memory_manager->strings, chars, length, hash);
  if (interned != NULL) {
    MemoryAllocator_free_array(chars, sizeof(char), length + 1);
    return interned;
  }

  return MemoryManager_allocate_string(memory_manager, chars, length, hash);
}

void MemoryManager_free(MemoryManager* memory_manager) {
  Obj* object = memory_manager->objects;
  while (object != NULL) {
    Obj* next = object->next;
    MemoryAllocator_free_object(object);
    object = next;
  }

  Table_free(&memory_manager->strings);
}

Obj* memorymanager_allocate_new(MemoryManager* memory_manager, size_t size, ObjType type) {
  Obj* object = (Obj*)MemoryAllocator_reallocate(NULL, 0, size);
  object->type = type;

  object->next = memory_manager->objects;
  memory_manager->objects = object;

  return object;
}

static uint32_t memorymanager_hash_string(char* key, int length) {
  uint32_t hash = 2166136261u;
  for (int i = 0; i < length; i++) {
    hash ^= (uint8_t)key[i];
    hash *= 16777619;
  }
  return hash;
}
