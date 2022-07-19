#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include "common.h"
#include "memory.h"
#include "object.h"
#include "table.h"
#include "value.h"
#include "vm.h"

static void vm_reset_stack(VM* vm);
static InterpretResult vm_run(VM* vm);
static inline InterpretResult vm_run_instruction(VM* vm);
static Value vm_stack_peek(VM* vm, int distance);
static bool vm_is_falsey(Value value);
static void vm_runtime_error(VM* vm, const char* format, ...);
static void vm_concatenate(VM* vm);
static ObjString* vm_allocate_string(VM* vm, char* chars, int length, uint32_t hash);
static ObjString* vm_allocate_new_string(VM* vm);
static uint32_t vm_hash_string(char* chars, int length);

void VM_init(VM* vm) {
  vm_reset_stack(vm);
  vm->objects = NULL;
  Table_init(&vm->globals);
  Table_init(&vm->strings);
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

void VM_push(VM* vm, Value value) {
  *vm->stack_top = value;
  *vm->stack_top++;
}

Value VM_pop(VM* vm) {
  *vm->stack_top--;
  return *vm->stack_top;
}

ObjString* VM_copy_string(VM* vm, char* chars, int length) {
  uint32_t hash = vm_hash_string(chars, length);
  ObjString* interned = Table_find_string(&vm->strings, chars, length, hash);
  if (interned != NULL) {
    return interned;
  }

  char* heap_chars = Memory_allocate_chars(length + 1);
  memcpy(heap_chars, chars, length);
  heap_chars[length] = '\0';
  return vm_allocate_string(vm, heap_chars, length, hash);
}

ObjString* VM_take_string(VM* vm, char* chars, int length) {
  uint32_t hash = vm_hash_string(chars, length);
  ObjString* interned = Table_find_string(&vm->strings, chars, length, hash);
  if (interned != NULL) {
    Memory_free_array(chars, sizeof(char), length + 1);
    return interned;
  }

  return vm_allocate_string(vm, chars, length, hash);
}

void VM_free(VM* vm) {
  Table_free(&vm->strings);
  Table_free(&vm->globals);
  Memory_free_objects(vm);
}

static void vm_reset_stack(VM* vm) {
  vm->stack_top = vm->stack;
}

static inline uint8_t vm_read_byte(VM* vm) {
  return *vm->ip++;
}

static inline Value vm_read_constant(VM* vm) {
  return vm->chunk->constants.values[vm_read_byte(vm)];
}

static inline ObjString* vm_read_string(VM* vm) {
  return Object_as_string(vm_read_constant(vm));
}

static inline InterpretResult vm_run_instruction(VM* vm) {
  uint8_t instruction;
  switch (instruction = vm_read_byte(vm)) {
    case OP_CONSTANT: {
      Value constant = vm_read_constant(vm);
      VM_push(vm, constant);
      break;
    }
    case OP_NIL:
      VM_push(vm, Value_make_nil());
      break;
    case OP_TRUE:
      VM_push(vm, Value_make_boolean(true));
      break;
    case OP_FALSE:
      VM_push(vm, Value_make_boolean(false));
      break;
    case OP_POP:
      VM_pop(vm);
      break;
    case OP_GET_GLOBAL: {
      ObjString* name = vm_read_string(vm);
      Value value;
      if (!Table_get(&vm->globals, name, &value)) {
        vm_runtime_error(vm, "Undefined variable '%s'.", name->chars);
        return INTERPRET_RUNTIME_ERROR;
      }
      VM_push(vm, value);
      break;
    }
    case OP_DEFINE_GLOBAL: {
      ObjString* name = vm_read_string(vm);
      Table_set(&vm->globals, name, vm_stack_peek(vm, 0));
      VM_pop(vm);
      break;
    }
    case OP_SET_GLOBAL: {
      ObjString* name = vm_read_string(vm);
      if (Table_set(&vm->globals, name, vm_stack_peek(vm, 0))) {
        Table_delete(&vm->globals, name);
        vm_runtime_error(vm, "Undefined variable '%s'.", name->chars);
        return INTERPRET_RUNTIME_ERROR;
      }
      break;
    }
    case OP_EQUAL: {
      Value b = VM_pop(vm);
      Value a = VM_pop(vm);
      VM_push(vm, Value_make_boolean(Value_equals(a, b)));
      break;
    }
    case OP_GREATER: {
      if (!Value_is_number(vm_stack_peek(vm, 0)) || !Value_is_number(vm_stack_peek(vm, 1))) {
        vm_runtime_error(vm, "Operands must be numbers.");
        return INTERPRET_RUNTIME_ERROR;
      }
      double b = Value_as_number(VM_pop(vm));
      double a = Value_as_number(VM_pop(vm));
      VM_push(vm, Value_make_boolean(a > b));
      break;
    }
    case OP_LESS: {
      if (!Value_is_number(vm_stack_peek(vm, 0)) || !Value_is_number(vm_stack_peek(vm, 1))) {
        vm_runtime_error(vm, "Operands must be numbers.");
        return INTERPRET_RUNTIME_ERROR;
      }
      double b = Value_as_number(VM_pop(vm));
      double a = Value_as_number(VM_pop(vm));
      VM_push(vm, Value_make_boolean(a < b));
      break;
    }
    case OP_ADD: {
      if (Object_is_string(vm_stack_peek(vm, 0)) && Object_is_string(vm_stack_peek(vm, 1))) {
        vm_concatenate(vm);
      } else if (Value_is_number(vm_stack_peek(vm, 0)) && Value_is_number(vm_stack_peek(vm, 1))) {
        double b = Value_as_number(VM_pop(vm));
        double a = Value_as_number(VM_pop(vm));
        VM_push(vm, Value_make_number(a + b));
      } else {
        vm_runtime_error(vm, "Operands must be two numbers or two strings.");
        return INTERPRET_RUNTIME_ERROR;
      }
      break;
    }
    case OP_SUBTRACT: {
      if (!Value_is_number(vm_stack_peek(vm, 0)) || !Value_is_number(vm_stack_peek(vm, 1))) {
        vm_runtime_error(vm, "Operands must be numbers.");
        return INTERPRET_RUNTIME_ERROR;
      }
      double b = Value_as_number(VM_pop(vm));
      double a = Value_as_number(VM_pop(vm));
      VM_push(vm, Value_make_number(a - b));
      break;
    }
    case OP_MULTIPLY: {
      if (!Value_is_number(vm_stack_peek(vm, 0)) || !Value_is_number(vm_stack_peek(vm, 1))) {
        vm_runtime_error(vm, "Operands must be numbers.");
        return INTERPRET_RUNTIME_ERROR;
      }
      double b = Value_as_number(VM_pop(vm));
      double a = Value_as_number(VM_pop(vm));
      VM_push(vm, Value_make_number(a * b));
      break;
    }
    case OP_DIVIDE: {
      if (!Value_is_number(vm_stack_peek(vm, 0)) || !Value_is_number(vm_stack_peek(vm, 1))) {
        vm_runtime_error(vm, "Operands must be numbers.");
        return INTERPRET_RUNTIME_ERROR;
      }
      double b = Value_as_number(VM_pop(vm));
      double a = Value_as_number(VM_pop(vm));
      VM_push(vm, Value_make_number(a / b));
      break;
    }
    case OP_NOT:
      VM_push(vm, Value_make_boolean(vm_is_falsey(VM_pop(vm))));
      break;
    case OP_NEGATE:
      if (!Value_is_number(vm_stack_peek(vm, 0))) {
        vm_runtime_error(vm, "Operand must be a number.");
        return INTERPRET_RUNTIME_ERROR;
      }
      VM_push(vm, Value_make_number(-Value_as_number(VM_pop(vm))));
      break;
    case OP_PRINT: {
      Value_print(VM_pop(vm));
      printf("\n");
      break;
    }
    case OP_RETURN:
      return INTERPRET_OK;
    default:
      return INTERPRET_RUNTIME_ERROR;
  }
  return INTERPRET_INCOMPLETE;
}

static InterpretResult vm_run(VM* vm) {
  for (;;) {
    InterpretResult result = vm_run_instruction(vm);
    if (result != INTERPRET_INCOMPLETE) {
      return result;
    }
  }
}

static Value vm_stack_peek(VM* vm, int distance) {
  return vm->stack_top[-1 - distance];
}

static bool vm_is_falsey(Value value) {
  return Value_is_nil(value) || (Value_is_boolean(value) && !Value_as_boolean(value));
}

static void vm_runtime_error(VM* vm, const char* format, ...) {
  va_list args;
  va_start(args, format);
  vfprintf(stderr, format, args);
  va_end(args);
  fputs("\n", stderr);

  size_t instruction = vm->ip - vm->chunk->code - 1;
  int line = vm->chunk->lines[instruction];
  fprintf(stderr, "[line %d] in script\n", line);
  vm_reset_stack(vm);
}

static void vm_concatenate(VM *vm) {
  ObjString* b = Object_as_string(VM_pop(vm));
  ObjString* a = Object_as_string(VM_pop(vm));

  int length = a->length + b->length;
  char* chars = Memory_allocate_chars(length + 1);
  memcpy(chars, a->chars, a->length);
  memcpy(chars + a->length, b->chars, b->length);
  chars[length] = '\0';

  ObjString* result = VM_take_string(vm, chars, length);
  VM_push(vm, Value_make_obj((Obj*)result));
}

static ObjString* vm_allocate_string(VM* vm, char* chars, int length, uint32_t hash) {
  ObjString* string = vm_allocate_new_string(vm);
  string->length = length;
  string->chars = chars;
  string->hash = hash;
  Table_set(&vm->strings, string, Value_make_nil());
  return string;
}

static Obj* vm_allocate_new(VM* vm, size_t size, ObjType type) {
  Obj* object = (Obj*)Memory_reallocate(NULL, 0, size);
  object->type = type;

  object->next = vm->objects;
  vm->objects = object;

  return object;
}

static ObjString* vm_allocate_new_string(VM* vm) {
  return (ObjString*)vm_allocate_new(vm, sizeof(ObjString), OBJ_STRING);
}

static uint32_t vm_hash_string(char* key, int length) {
  uint32_t hash = 2166136261u;
  for (int i = 0; i < length; i++) {
    hash ^= (uint8_t)key[i];
    hash *= 16777619;
  }
  return hash;
}
