#ifndef clox_memory_manager_h
#define clox_memory_manager_h

#include "common.h"
#include "object.h"
#include "table.h"

typedef struct {
  MemoryAllocator memory_allocator;
  Table strings;
} MemoryManager;

void MemoryManager_init(MemoryManager* memory_manager);

ObjString* MemoryManager_copy_string(MemoryManager* memory_manager, char* chars, int length);
ObjString* MemoryManager_take_string(MemoryManager* memory_manager, char* chars, int length);

void MemoryManager_free(MemoryManager* memory_manager);

#endif
