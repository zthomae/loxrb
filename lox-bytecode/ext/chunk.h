#ifndef clox_chunk_h
#define clox_chunk_h

#include "common.h"
#include "value_array.h"
#include "object_types.h"
#include "memory_allocator.h"

typedef enum {
  OP_CONSTANT,
  OP_NIL,
  OP_TRUE,
  OP_FALSE,
  OP_POP,
  OP_GET_LOCAL,
  OP_SET_LOCAL,
  OP_GET_GLOBAL,
  OP_DEFINE_GLOBAL,
  OP_SET_GLOBAL,
  OP_GET_UPVALUE,
  OP_SET_UPVALUE,
  OP_GET_PROPERTY,
  OP_SET_PROPERTY,
  OP_EQUAL,
  OP_GREATER,
  OP_LESS,
  OP_ADD,
  OP_SUBTRACT,
  OP_MULTIPLY,
  OP_DIVIDE,
  OP_NOT,
  OP_NEGATE,
  OP_PRINT,
  OP_JUMP,
  OP_JUMP_IF_FALSE,
  OP_LOOP,
  OP_CALL,
  OP_CLOSURE,
  OP_CLOSE_UPVALUE,
  OP_RETURN,
  OP_CLASS,
  OP_METHOD
} OpCode;

typedef struct {
  int capacity;
  int count;
  uint8_t* code;
  int* lines;
  ValueArray constants;
  MemoryAllocator* memory_allocator;
} Chunk;

void Chunk_init(Chunk* chunk, MemoryAllocator* memory_allocator);
void Chunk_write(Chunk* chunk, uint8_t byte, int line);
void Chunk_free(Chunk* chunk);
int Chunk_add_number(Chunk* chunk, double number);
int Chunk_add_object(Chunk* chunk, Obj* object);

#endif
