#include <stdlib.h>

#include "chunk.h"
#include "memory.h"

void Chunk_init(Chunk* chunk) {
  chunk->count = 0;
  chunk->capacity = 0;
  chunk->code = NULL;
  chunk->lines = NULL;
  ValueArray_init(&chunk->constants);
}

void Chunk_write(Chunk* chunk, uint8_t byte, int line) {
  if (chunk->capacity < chunk->count + 1) {
    int old_capacity = chunk->capacity;
    chunk->capacity = Memory_grow_capacity(old_capacity);
    chunk->code = (uint8_t*) Memory_grow_array(chunk->code, sizeof(uint8_t), old_capacity, chunk->capacity);
    chunk->lines = (int*) Memory_grow_array(chunk->lines, sizeof(int), old_capacity, chunk->capacity);
  }

  chunk->code[chunk->count] = byte;
  chunk->lines[chunk->count] = line;
  chunk->count++;
}

void Chunk_free(Chunk* chunk) {
  Memory_free_array(chunk->code, sizeof(uint8_t), chunk->capacity);
  Memory_free_array(chunk->lines, sizeof(int), chunk->capacity);
  ValueArray_free(&chunk->constants);
  Chunk_init(chunk);
}

int Chunk_add_number(Chunk* chunk, double number) {
  ValueArray_write(&chunk->constants, Value_make_number(number));
  return chunk->constants.count - 1;
}
