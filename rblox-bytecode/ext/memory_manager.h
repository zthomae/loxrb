#ifndef clox_memory_manager_h
#define clox_memory_manager_h

#include "common.h"
#include "object.h"
#include "table.h"

typedef struct {
  Table strings;
  Obj* objects;
} MemoryManager;

void MemoryManager_init(MemoryManager* memory_manager);

ObjString* MemoryManager_allocate_string(MemoryManager* memory_manager, char* chars, int length, uint32_t hash);
ObjString* MemoryManager_allocate_new_string(MemoryManager* memory_manager);
ObjFunction* MemoryManager_allocate_new_function(MemoryManager* memory_manager);
ObjNative* MemoryManager_allocate_new_native(MemoryManager* memory_manager, NativeFn function);
ObjClosure* MemoryManager_allocate_new_closure(MemoryManager* memory_manager, ObjFunction* function);
ObjUpvalue* MemoryManager_allocate_new_upvalue(MemoryManager* memory_manager, Value* local);

ObjString* MemoryManager_copy_string(MemoryManager* memory_manager, char* chars, int length);
ObjString* MemoryManager_take_string(MemoryManager* memory_manager, char* chars, int length);

void MemoryManager_free(MemoryManager* memory_manager);

#endif
