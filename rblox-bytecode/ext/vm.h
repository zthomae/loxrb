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
  ObjUpvalue* open_upvalues;
  Obj* objects;
  bool log_gc;
  bool stress_gc;
} Vm;

typedef enum {
  INTERPRET_INCOMPLETE,
  INTERPRET_OK,
  INTERPRET_COMPILE_ERROR,
  INTERPRET_RUNTIME_ERROR
} InterpretResult;

void Vm_init(Vm* vm);
void Vm_init_function(Vm* vm, ObjFunction* function);
InterpretResult Vm_interpret(Vm* vm, ObjFunction* function);
InterpretResult Vm_interpret_next_instruction(Vm* vm);

ObjFunction* Vm_new_function(Vm* vm);

void Vm_free(Vm* vm);

#endif
