#ifndef clox_chunk_h
#define clox_chunk_h

#include "common.h"
#include "value.h"

typedef enum {
  OP_CONSTANT,
  OP_RETURN,
} OpCode;

typedef struct {
  int capacity;
  int count;
  uint8_t* code;
  int* lines;
  ValueArray constants;
} Chunk;

void Chunk_init(Chunk* chunk);
void Chunk_write(Chunk* chunk, uint8_t byte, int line);
void Chunk_free(Chunk* chunk);
int Chunk_add_constant(Chunk* chunk, Value value);

#endif