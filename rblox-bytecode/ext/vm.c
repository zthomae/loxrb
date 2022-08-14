#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#include "common.h"
#include "memory.h"
#include "object.h"
#include "table.h"
#include "value.h"
#include "vm.h"

static CallFrame* vm_current_frame(VM* vm);
static void vm_reset_stack(VM* vm);
static InterpretResult vm_run(VM* vm);
static inline InterpretResult vm_run_instruction(VM* vm);
static Value vm_stack_peek(VM* vm, int distance);
static bool vm_is_falsey(Value value);
static void vm_runtime_error(VM* vm, const char* format, ...);
static void vm_concatenate(VM* vm);
static ObjString* vm_allocate_string(VM* vm, char* chars, int length, uint32_t hash);
static ObjString* vm_allocate_new_string(VM* vm);
static ObjFunction* vm_allocate_new_function(VM* vm);
static ObjNative* vm_allocate_new_native(VM* vm, NativeFn function);
static ObjClosure* vm_allocate_new_closure(VM* vm, ObjFunction* function);
static uint32_t vm_hash_string(char* chars, int length);
static bool vm_call(VM* vm, ObjClosure* closure, int arg_count);
static bool vm_call_value(VM* vm, Value callee, int arg_count);
static void vm_define_native(VM* vm, char* name, NativeFn function);
static ObjUpvalue* vm_capture_upvalue(VM* vm, Value* local);

static Value vm_clock_native(int arg_count, Value* args) {
  return Value_make_number((double)clock() / CLOCKS_PER_SEC);
}

void VM_init(VM* vm) {
  vm_reset_stack(vm);
  vm->objects = NULL;
  Table_init(&vm->globals);
  Table_init(&vm->strings);

  vm_define_native(vm, "clock", vm_clock_native);
}

void VM_init_function(VM* vm, ObjFunction* function) {
  VM_push(vm, Value_make_obj((Obj*)function));
  ObjClosure* closure = vm_allocate_new_closure(vm, function);
  VM_pop(vm);
  VM_push(vm, Value_make_obj((Obj*)closure));
  vm_call(vm, closure, 0);
}

InterpretResult VM_interpret(VM* vm, ObjFunction* function) {
  VM_init_function(vm, function);
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

ObjFunction* VM_new_function(VM* vm) {
  ObjFunction* function = vm_allocate_new_function(vm);
  function->arity = 0;
  function->upvalue_count = 0;
  function->name = NULL;
  Chunk_init(&function->chunk);
  return function;
}

void VM_free(VM* vm) {
  Table_free(&vm->strings);
  Table_free(&vm->globals);
  Memory_free_objects(vm);
}

static CallFrame* vm_current_frame(VM* vm) {
  return &vm->frames[vm->frame_count - 1];
}

static void vm_reset_stack(VM* vm) {
  vm->stack_top = vm->stack;
  vm->frame_count = 0;
}

static inline uint8_t vm_read_byte(CallFrame* call_frame) {
  return *call_frame->ip++;
}

static inline uint16_t vm_read_short(CallFrame* call_frame) {
  call_frame->ip += 2;
  return (uint16_t)((call_frame->ip[-2] << 8) | call_frame->ip[-1]);
}

static inline Value vm_read_constant(CallFrame* call_frame) {
  return call_frame->closure->function->chunk.constants.values[vm_read_byte(call_frame)];
}

static inline ObjString* vm_read_string(CallFrame* call_frame) {
  return Object_as_string(vm_read_constant(call_frame));
}

static inline InterpretResult vm_run_instruction(VM* vm) {
  CallFrame* call_frame = vm_current_frame(vm);
  uint8_t instruction;
  switch (instruction = vm_read_byte(call_frame)) {
    case OP_CONSTANT: {
      Value constant = vm_read_constant(call_frame);
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
    case OP_GET_LOCAL: {
      uint8_t slot = vm_read_byte(call_frame);
      VM_push(vm, call_frame->slots[slot]);
      break;
    }
    case OP_SET_LOCAL: {
      uint8_t slot = vm_read_byte(call_frame);
      call_frame->slots[slot] = vm_stack_peek(vm, 0);
      break;
    }
    case OP_GET_GLOBAL: {
      ObjString* name = vm_read_string(call_frame);
      Value value;
      if (!Table_get(&vm->globals, name, &value)) {
        vm_runtime_error(vm, "Undefined variable '%s'.", name->chars);
        return INTERPRET_RUNTIME_ERROR;
      }
      VM_push(vm, value);
      break;
    }
    case OP_DEFINE_GLOBAL: {
      ObjString* name = vm_read_string(call_frame);
      Table_set(&vm->globals, name, vm_stack_peek(vm, 0));
      VM_pop(vm);
      break;
    }
    case OP_SET_GLOBAL: {
      ObjString* name = vm_read_string(call_frame);
      if (Table_set(&vm->globals, name, vm_stack_peek(vm, 0))) {
        Table_delete(&vm->globals, name);
        vm_runtime_error(vm, "Undefined variable '%s'.", name->chars);
        return INTERPRET_RUNTIME_ERROR;
      }
      break;
    }
    case OP_GET_UPVALUE: {
      uint8_t slot = vm_read_byte(call_frame);
      VM_push(vm, *call_frame->closure->upvalues[slot]->location);
      break;
    }
    case OP_SET_UPVALUE: {
      uint8_t slot = vm_read_byte(call_frame);
      *call_frame->closure->upvalues[slot]->location = vm_stack_peek(vm, 0);
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
    case OP_JUMP: {
      uint16_t offset = vm_read_short(call_frame);
      call_frame->ip += offset;
      break;
    }
    case OP_JUMP_IF_FALSE: {
      uint16_t offset = vm_read_short(call_frame);
      if (vm_is_falsey(vm_stack_peek(vm, 0))) {
        call_frame->ip += offset;
      }
      break;
    }
    case OP_LOOP: {
      uint16_t offset = vm_read_short(call_frame);
      call_frame->ip -= offset;
      break;
    }
    case OP_CALL: {
      int arg_count = vm_read_byte(call_frame);
      if (!vm_call_value(vm, vm_stack_peek(vm, arg_count), arg_count)) {
        return INTERPRET_RUNTIME_ERROR;
      }
      break;
    }
    case OP_CLOSURE: {
      ObjFunction* function = Object_as_function(vm_read_constant(call_frame));
      ObjClosure* closure = vm_allocate_new_closure(vm, function);
      VM_push(vm, Value_make_obj((Obj*)closure));
      for (int i = 0; i < closure->upvalue_count; i++) {
        uint8_t is_local = vm_read_byte(call_frame);
        uint8_t index = vm_read_byte(call_frame);
        if (is_local) {
          closure->upvalues[i] = vm_capture_upvalue(vm, call_frame->slots + index);
        } else {
          closure->upvalues[i] = call_frame->closure->upvalues[index];
        }
      }
      break;
    }
    case OP_RETURN: {
      Value result = VM_pop(vm);
      vm->frame_count--;
      if (vm->frame_count == 0) {
        VM_pop(vm);
        return INTERPRET_OK;
      }

      vm->stack_top = call_frame->slots - 1;
      VM_push(vm, result);
      break;
    }
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

static bool vm_call(VM* vm, ObjClosure* closure, int arg_count) {
  if (arg_count != closure->function->arity) {
    vm_runtime_error(vm, "Expected %d arguments but got %d.", closure->function->arity, arg_count);
    return false;
  }

  if (vm->frame_count == FRAMES_MAX) {
    vm_runtime_error(vm, "Stack overflow.");
    return false;
  }

  CallFrame* frame = &vm->frames[vm->frame_count++];
  frame->closure = closure;
  frame->ip = closure->function->chunk.code;
  frame->slots = vm->stack_top - arg_count; // The book subtracts one more here...
  return true;
}

static bool vm_call_value(VM* vm, Value callee, int arg_count) {
  if (Value_is_obj(callee)) {
    switch (Object_type(callee)) {
      case OBJ_CLOSURE:
        return vm_call(vm, Object_as_closure(callee), arg_count);
      case OBJ_NATIVE: {
        NativeFn native = Object_as_native(callee);
        Value result = native(arg_count, vm->stack_top - arg_count);
        vm->stack_top -= arg_count + 1;
        VM_push(vm, result);
        return true;
      }
      default:
        break;
    }
  }
  vm_runtime_error(vm, "Can only call functions and classes.");
  return false;
}

static void vm_runtime_error(VM* vm, const char* format, ...) {
  va_list args;
  va_start(args, format);
  vfprintf(stderr, format, args);
  va_end(args);
  fputs("\n", stderr);

  // CallFrame* call_frame = vm_current_frame(vm);
  // Chunk chunk = call_frame->function->chunk;

  // size_t instruction = call_frame->ip - chunk.code - 1;
  // int line = chunk.lines[instruction];
  // fprintf(stderr, "[line %d] in script\n", line);

  for (int i = vm->frame_count - 1; i >= 0; i--) {
    CallFrame* frame = &vm->frames[i];
    ObjFunction* function = frame->closure->function;
    size_t instruction = frame->ip - function->chunk.code - 1;
    fprintf(stderr, "[line %d] in ", function->chunk.lines[instruction]);
    if (function->name == NULL) {
      fprintf(stderr, "script\n");
    } else {
      fprintf(stderr, "%s()\n", function->name->chars);
    }
  }

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

static ObjUpvalue* vm_allocate_new_upvalue(VM* vm, Value* slot) {
  ObjUpvalue* upvalue = (ObjUpvalue*)vm_allocate_new(vm, sizeof(ObjUpvalue), OBJ_UPVALUE);
  upvalue->location = slot;
  return upvalue;
}

static uint32_t vm_hash_string(char* key, int length) {
  uint32_t hash = 2166136261u;
  for (int i = 0; i < length; i++) {
    hash ^= (uint8_t)key[i];
    hash *= 16777619;
  }
  return hash;
}

static ObjFunction* vm_allocate_new_function(VM* vm) {
  return (ObjFunction*)vm_allocate_new(vm, sizeof(ObjFunction), OBJ_FUNCTION);
}

static ObjNative* vm_allocate_new_native(VM* vm, NativeFn function) {
  ObjNative* native = (ObjNative*)vm_allocate_new(vm, sizeof(ObjNative), OBJ_NATIVE);
  native->function = function;
  return native;
}

static ObjClosure* vm_allocate_new_closure(VM* vm, ObjFunction* function) {
  ObjUpvalue** upvalues = Memory_allocate(sizeof(ObjUpvalue*), function->upvalue_count);
  for (int i = 0; i < function->upvalue_count; i++) {
    upvalues[i] = NULL;
  }
  ObjClosure* closure = (ObjClosure*)vm_allocate_new(vm, sizeof(ObjClosure), OBJ_CLOSURE);
  closure->function = function;
  closure->upvalues = upvalues;
  closure->upvalue_count = function->upvalue_count;
  return closure;
}

static void vm_define_native(VM* vm, char* name, NativeFn function) {
  VM_push(vm, Value_make_obj((Obj*)VM_copy_string(vm, name, (int)strlen(name))));
  VM_push(vm, Value_make_obj((Obj*)vm_allocate_new_native(vm, function)));
  Table_set(&vm->globals, Object_as_string(vm_stack_peek(vm, 1)), vm_stack_peek(vm, 0));
  VM_pop(vm);
  VM_pop(vm);
}

static ObjUpvalue* vm_capture_upvalue(VM* vm, Value* local) {
  ObjUpvalue* created_upvalue = vm_allocate_new_upvalue(vm, local);
  return created_upvalue;
}
