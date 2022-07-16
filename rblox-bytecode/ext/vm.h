#ifndef clox_vm_h
#define clox_vm_h

#include "chunk.h"
#include "value.h"

#define STACK_MAX 256

typedef struct {
  Chunk* chunk;
  uint8_t* ip;
  Value stack[STACK_MAX];
  Value* stack_top;
} VM;

typedef enum {
  INTERPRET_INCOMPLETE,
  INTERPRET_OK,
  INTERPRET_COMPILE_ERROR,
  INTERPRET_RUNTIME_ERROR
} InterpretResult;

void VM_init(VM* vm);
void VM_init_chunk(VM* vm, Chunk* chunk);
InterpretResult VM_interpret(VM* vm, Chunk* chunk);
InterpretResult VM_interpret_next_instruction(VM* vm);
void VM_push(VM* vm, Value value);
Value VM_pop(VM* vm);
void VM_free(VM* vm);

#endif
