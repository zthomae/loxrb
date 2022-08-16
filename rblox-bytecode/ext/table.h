#ifndef clox_table_h
#define clox_table_h

#include "common.h"
#include "value.h"
#include "memory_allocator.h"

typedef struct {
  ObjString* key;
  Value value;
} Entry;

typedef struct {
  int count;
  int capacity;
  Entry* entries;
  MemoryAllocator* memory_allocator;
} Table;

void Table_init(Table* table, MemoryAllocator* memory_allocator);
void Table_free(Table* table);

bool Table_set(Table* table, ObjString* key, Value value);
void Table_add_all(Table* from, Table* to);
ObjString* Table_find_string(Table* table, char* chars, int length, uint32_t hash);
bool Table_get(Table* table, ObjString* key, Value* value);
bool Table_delete(Table* table, ObjString* key);

#endif
