#ifndef clox_vm_h
#define clox_vm_h

#include "chunk.h"
#include "object.h"
#include "value.h"

#define STACK_MAX 256

typedef struct {
  Chunk* chunk;
  uint8_t* ip;
  Value stack[STACK_MAX];
  Value* stack_top;
  Obj* objects;
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

ObjString* VM_copy_string(VM* vm, char* chars, int length);
ObjString* VM_take_string(VM* vm, char* chars, int length);

void VM_free(VM* vm);

#endif
