#ifndef clox_vm_h
#define clox_vm_h

#include "chunk.h"
#include "object.h"
#include "table.h"
#include "value.h"

#define FRAMES_MAX 64
#define STACK_MAX (FRAMES_MAX * 256)

typedef struct {
  ObjClosure* closure;
  uint8_t* ip;
  Value* slots; // Points into the VM's stack to the first slot this function can use
} CallFrame;

typedef struct {
  CallFrame frames[FRAMES_MAX];
  int frame_count;
  Value stack[STACK_MAX];
  Value* stack_top;
  Table globals;
  Table strings;
  Obj* objects;
} VM;

typedef enum {
  INTERPRET_INCOMPLETE,
  INTERPRET_OK,
  INTERPRET_COMPILE_ERROR,
  INTERPRET_RUNTIME_ERROR
} InterpretResult;

void VM_init(VM* vm);
void VM_init_function(VM* vm, ObjFunction* function);
InterpretResult VM_interpret(VM* vm, ObjFunction* function);
InterpretResult VM_interpret_next_instruction(VM* vm);
void VM_push(VM* vm, Value value);
Value VM_pop(VM* vm);

ObjString* VM_copy_string(VM* vm, char* chars, int length);
ObjString* VM_take_string(VM* vm, char* chars, int length);

ObjFunction* VM_new_function(VM* vm);

void VM_free(VM* vm);

#endif
