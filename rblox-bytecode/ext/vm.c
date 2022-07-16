#include <stdio.h>

#include "common.h"
#include "vm.h"

static InterpretResult vm_run(VM* vm);
static inline InterpretResult vm_run_instruction(VM* vm);

void VM_init(VM* vm) {

}

void VM_init_chunk(VM* vm, Chunk* chunk) {
  vm->chunk = chunk;
  vm->ip = vm->chunk->code;
}

InterpretResult VM_interpret(VM* vm, Chunk* chunk) {
  VM_init_chunk(vm, chunk);
  return vm_run(vm);
}

InterpretResult VM_interpret_next_instruction(VM* vm) {
  return vm_run_instruction(vm);
}

void VM_free(VM* vm) {

}

static inline uint8_t vm_read_byte(VM* vm) {
  return *vm->ip++;
}

static inline Value vm_read_constant(VM* vm) {
  return vm->chunk->constants.values[vm_read_byte(vm)];
}

static inline InterpretResult vm_run_instruction(VM* vm) {
  uint8_t instruction;
  switch (instruction = vm_read_byte(vm)) {
    case OP_CONSTANT: {
      Value constant = vm_read_constant(vm);
      Value_print(constant);
      printf("\n");
      return INTERPRET_INCOMPLETE;
    }
    case OP_RETURN: {
      return INTERPRET_OK;
    }
    default: {
      return INTERPRET_RUNTIME_ERROR;
    }
  }
}

static InterpretResult vm_run(VM* vm) {
  for (;;) {
    InterpretResult result = vm_run_instruction(vm);
    if (result != INTERPRET_INCOMPLETE) {
      return result;
    }
  }
}
