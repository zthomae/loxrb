#include <stdlib.h>
#include <string.h>

#include "memory_allocator.h"
#include "object.h"
#include "table.h"
#include "value.h"

#define TABLE_MAX_LOAD 0.75

static Entry* table_find_entry(Entry* entries, int capacity, ObjString* key);
static void table_adjust_capacity(Table* table, int new_capacity);

void Table_init(Table* table, MemoryAllocator* memory_allocator) {
  table->count = 0;
  table->capacity = 0;
  table->entries = NULL;
  table->memory_allocator = memory_allocator;
}

void Table_free(Table* table) {
  MemoryAllocator_free_array(table->entries, sizeof(Entry), table->capacity);
  Table_init(table, table->memory_allocator);
}

bool Table_set(Table* table, ObjString* key, Value value) {
  if (table->count + 1 > table->capacity * TABLE_MAX_LOAD) {
    int capacity = MemoryAllocator_grow_capacity(table->capacity);
    table_adjust_capacity(table, capacity);
  }

  Entry* entry = table_find_entry(table->entries, table->capacity, key);
  bool is_new_key = entry->key == NULL;
  if (is_new_key && Value_is_nil(entry->value)) {
    table->count++;
  }

  entry->key = key;
  entry->value = value;
  return is_new_key;
}

void Table_add_all(Table* from, Table* to) {
  for (int i = 0; i < from->capacity; i++) {
    Entry entry = from->entries[i];
    if (entry.key != NULL) {
      Table_set(to, entry.key, entry.value);
    }
  }
}

ObjString* Table_find_string(Table* table, char* chars, int length, uint32_t hash) {
  if (table->count == 0){
    return NULL;
  }

  uint32_t index = hash % table->capacity;

  // This function will not be called unless the load factor is less than
  // TABLE_MAX_LOAD. Under this condition the for loop below is guaranteed to
  // terminate.
  for (;;) {
    Entry* entry = &table->entries[index];
    if (entry->key == NULL) {
      if (Value_is_nil(entry->value)) {
        return NULL;
      }
    } else if (
        entry->key->length == length &&
        entry->key->hash == hash &&
        memcmp(entry->key->chars, chars, length) == 0
    ) {
      return entry->key;
    }

    index = (index + 1) % table->capacity;
  }
}

bool Table_get(Table* table, ObjString* key, Value* value) {
  if (table->count == 0) {
    return false;
  }

  Entry* entry = table_find_entry(table->entries, table->capacity, key);
  if (entry->key == NULL) {
    return false;
  }
  *value = entry->value;
  return true;
}

bool Table_delete(Table* table, ObjString* key) {
  if (table->count == 0) {
    return false;
  }

  Entry* entry = table_find_entry(table->entries, table->capacity, key);
  if (entry->key == NULL) {
    return false;
  }

  entry->key = NULL;
  entry->value = Value_make_boolean(true);
  return true;
}

static Entry* table_find_entry(Entry* entries, int capacity, ObjString* key) {
  uint32_t index = key->hash % capacity;
  Entry* tombstone = NULL;

  // This function will not be called unless the load factor is less than
  // TABLE_MAX_LOAD. Under this condition the for loop below is guaranteed to
  // terminate.
  for (;;) {
    Entry* entry = &entries[index];
    if (entry->key == NULL) {
      if (Value_is_nil(entry->value)) {
        // We return a tombstone if we have one to reuse it, instead of having
        // to use a fresh new entry.
        return tombstone != NULL ? tombstone : entry;
      } else {
        if (tombstone == NULL) {
          tombstone = entry;
        }
      }
    } else if (entry->key == key) {
      return entry;
    }

    index = (index + 1) % capacity;
  }
}

static void table_adjust_capacity(Table* table, int new_capacity) {
  Entry* new_entries = MemoryAllocator_allocate(sizeof(Entry), new_capacity);
  for (int i = 0; i < new_capacity; i++) {
    new_entries[i].key = NULL;
    new_entries[i].value = Value_make_nil();
  }

  // Place every entry from the original table into the new one by
  // redetermining the correct bucket. Don't copy tombstones.
  table->count = 0;
  for (int i = 0; i < table->capacity; i++) {
    Entry entry = table->entries[i];
    if (entry.key == NULL) {
      continue;
    }

    Entry* dest = table_find_entry(new_entries, new_capacity, entry.key);
    dest->key = entry.key;
    dest->value = entry.value;
    table->count++;
  }

  MemoryAllocator_free_array(table->entries, sizeof(Entry), table->capacity);
  table->entries = new_entries;
  table->capacity = new_capacity;
}
