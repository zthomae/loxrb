#include <stdlib.h>

#include "chunk.h"
#include "memory_allocator.h"
#include "base_object.h"

void Chunk_init(Chunk* chunk, MemoryAllocator* memory_allocator) {
  chunk->count = 0;
  chunk->capacity = 0;
  chunk->code = NULL;
  chunk->lines = NULL;
  chunk->memory_allocator = memory_allocator;
  ValueArray_init(&chunk->constants, chunk->memory_allocator);
}

void Chunk_write(Chunk* chunk, uint8_t byte, int line) {
  if (chunk->capacity < chunk->count + 1) {
    int old_capacity = chunk->capacity;
    chunk->capacity = MemoryAllocator_get_increased_capacity(chunk->memory_allocator, old_capacity);
    chunk->code = (uint8_t*) MemoryAllocator_grow_array(chunk->memory_allocator, chunk->code, sizeof(uint8_t), old_capacity, chunk->capacity);
    chunk->lines = (int*) MemoryAllocator_grow_array(chunk->memory_allocator, chunk->lines, sizeof(int), old_capacity, chunk->capacity);
  }

  chunk->code[chunk->count] = byte;
  chunk->lines[chunk->count] = line;
  chunk->count++;
}

void Chunk_free(Chunk* chunk) {
  MemoryAllocator_free_array(chunk->memory_allocator, chunk->code, sizeof(uint8_t), chunk->capacity);
  MemoryAllocator_free_array(chunk->memory_allocator, chunk->lines, sizeof(int), chunk->capacity);
  ValueArray_free(&chunk->constants);
  Chunk_init(chunk, chunk->memory_allocator);
}

int Chunk_add_number(Chunk* chunk, double number) {
  ValueArray_write(&chunk->constants, Value_make_number(number));
  return chunk->constants.count - 1;
}

int Chunk_add_object(Chunk* chunk, Obj* object) {
  ValueArray_write(&chunk->constants, Value_make_obj(object));
  return chunk->constants.count - 1;
}
