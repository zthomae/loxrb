#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#include "common.h"
#include "memory_allocator.h"
#include "object.h"
#include "table.h"
#include "value.h"
#include "vm.h"
#include "gc.h"

static uint32_t vm_hash_string(char* chars, int length);
static CallFrame* vm_current_frame(Vm* vm);
static void vm_reset_stack(Vm* vm);
static void vm_stack_push(Vm* vm, Value value);
static Value vm_stack_pop(Vm* vm);
static Value vm_stack_peek(Vm* vm, int distance);
static InterpretResult vm_run(Vm* vm);
static inline InterpretResult vm_run_instruction(Vm* vm);
static bool vm_is_falsey(Value value);
static void vm_runtime_error(Vm* vm, const char* format, ...);
static void vm_concatenate(Vm* vm);
static bool vm_call(Vm* vm, ObjClosure* closure, int arg_count);
static bool vm_call_value(Vm* vm, Value callee, int arg_count);
static void vm_define_native(Vm* vm, char* name, NativeFn function);
static ObjUpvalue* vm_capture_upvalue(Vm* vm, Value* local);
static void vm_close_upvalues(Vm* vm, Value* last);
static ObjString* vm_allocate_string(Vm* vm, char* chars, int length, uint32_t hash);

void vm_handle_new_object(void* callback_target, Obj* object) {
  Vm* vm = (Vm*) callback_target;
  object->next = vm->objects;
  vm->objects = object;
}

void vm_collect_garbage(void* callback_target) {
  Vm* vm = (Vm*) callback_target;
  Gc_collect(vm);
}

static Value vm_clock_native(int arg_count, Value* args) {
  return Value_make_number((double)clock() / CLOCKS_PER_SEC);
}

void Vm_init(Vm* vm) {
  vm_reset_stack(vm);
  vm->objects = NULL;
  vm->gray_count = 0;
  vm->gray_capacity = 0;
  vm->gray_stack = NULL;
  MemoryCallbacks memory_callbacks = {
    .handle_new_object = vm_handle_new_object,
    .collect_garbage = vm_collect_garbage
  };
  MemoryAllocator_init(&vm->memory_allocator, vm, memory_callbacks);
  Table_init(&vm->globals, &vm->memory_allocator);
  Table_init(&vm->strings, &vm->memory_allocator);

  vm_define_native(vm, "clock", vm_clock_native);
}

void Vm_init_function(Vm* vm, ObjFunction* function) {
  vm_stack_push(vm, Value_make_obj((Obj*)function));
  ObjClosure* closure = Object_allocate_new_closure(&vm->memory_allocator, function);
  vm_stack_pop(vm);
  vm_stack_push(vm, Value_make_obj((Obj*)closure));
  vm_call(vm, closure, 0);
}

InterpretResult Vm_interpret(Vm* vm, ObjFunction* function) {
  Vm_init_function(vm, function);
  return vm_run(vm);
}

InterpretResult Vm_interpret_next_instruction(Vm* vm) {
  return vm_run_instruction(vm);
}

static void vm_stack_push(Vm* vm, Value value) {
  *vm->stack_top = value;
  *vm->stack_top++;
}

static Value vm_stack_pop(Vm* vm) {
  *vm->stack_top--;
  return *vm->stack_top;
}

ObjFunction* Vm_new_function(Vm* vm) {
  ObjFunction* function = Object_allocate_new_function(&vm->memory_allocator);
  function->arity = 0;
  function->upvalue_count = 0;
  function->name = NULL;
  Chunk_init(&function->chunk, &vm->memory_allocator);
  return function;
}

ObjString* Vm_copy_string(Vm* vm, char* chars, int length) {
  uint32_t hash = vm_hash_string(chars, length);
  ObjString* interned = Table_find_string(&vm->strings, chars, length, hash);
  if (interned != NULL) {
    return interned;
  }

  char* heap_chars = MemoryAllocator_allocate_chars(&vm->memory_allocator, length + 1);
  memcpy(heap_chars, chars, length);
  heap_chars[length] = '\0';
  return vm_allocate_string(vm, heap_chars, length, hash);
}

ObjString* Vm_take_string(Vm* vm, char* chars, int length) {
  uint32_t hash = vm_hash_string(chars, length);
  ObjString* interned = Table_find_string(&vm->strings, chars, length, hash);
  if (interned != NULL) {
    MemoryAllocator_free_array(&vm->memory_allocator, chars, sizeof(char), length + 1);
    return interned;
  }

  return vm_allocate_string(vm, chars, length, hash);
}

void Vm_free(Vm* vm) {
  Table_free(&vm->globals);
  Obj* object = vm->objects;
  while (object != NULL) {
    Obj* next = object->next;
    Object_free(&vm->memory_allocator, object);
    object = next;
  }

  Table_free(&vm->strings);

  free(vm->gray_stack);
}

static uint32_t vm_hash_string(char* key, int length) {
  uint32_t hash = 2166136261u;
  for (int i = 0; i < length; i++) {
    hash ^= (uint8_t)key[i];
    hash *= 16777619;
  }
  return hash;
}


static CallFrame* vm_current_frame(Vm* vm) {
  return &vm->frames[vm->frame_count - 1];
}

static void vm_reset_stack(Vm* vm) {
  vm->stack_top = vm->stack;
  vm->frame_count = 0;
  vm->open_upvalues = NULL;
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

static inline InterpretResult vm_run_instruction(Vm* vm) {
  CallFrame* call_frame = vm_current_frame(vm);
  uint8_t instruction;
  switch (instruction = vm_read_byte(call_frame)) {
    case OP_CONSTANT: {
      Value constant = vm_read_constant(call_frame);
      vm_stack_push(vm, constant);
      break;
    }
    case OP_NIL:
      vm_stack_push(vm, Value_make_nil());
      break;
    case OP_TRUE:
      vm_stack_push(vm, Value_make_boolean(true));
      break;
    case OP_FALSE:
      vm_stack_push(vm, Value_make_boolean(false));
      break;
    case OP_POP:
      vm_stack_pop(vm);
      break;
    case OP_GET_LOCAL: {
      uint8_t slot = vm_read_byte(call_frame);
      vm_stack_push(vm, call_frame->slots[slot]);
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
      vm_stack_push(vm, value);
      break;
    }
    case OP_DEFINE_GLOBAL: {
      ObjString* name = vm_read_string(call_frame);
      Table_set(&vm->globals, name, vm_stack_peek(vm, 0));
      vm_stack_pop(vm);
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
      vm_stack_push(vm, *call_frame->closure->upvalues[slot]->location);
      break;
    }
    case OP_SET_UPVALUE: {
      uint8_t slot = vm_read_byte(call_frame);
      *call_frame->closure->upvalues[slot]->location = vm_stack_peek(vm, 0);
      break;
    }
    case OP_EQUAL: {
      Value b = vm_stack_pop(vm);
      Value a = vm_stack_pop(vm);
      vm_stack_push(vm, Value_make_boolean(Value_equals(a, b)));
      break;
    }
    case OP_GREATER: {
      if (!Value_is_number(vm_stack_peek(vm, 0)) || !Value_is_number(vm_stack_peek(vm, 1))) {
        vm_runtime_error(vm, "Operands must be numbers.");
        return INTERPRET_RUNTIME_ERROR;
      }
      double b = Value_as_number(vm_stack_pop(vm));
      double a = Value_as_number(vm_stack_pop(vm));
      vm_stack_push(vm, Value_make_boolean(a > b));
      break;
    }
    case OP_LESS: {
      if (!Value_is_number(vm_stack_peek(vm, 0)) || !Value_is_number(vm_stack_peek(vm, 1))) {
        vm_runtime_error(vm, "Operands must be numbers.");
        return INTERPRET_RUNTIME_ERROR;
      }
      double b = Value_as_number(vm_stack_pop(vm));
      double a = Value_as_number(vm_stack_pop(vm));
      vm_stack_push(vm, Value_make_boolean(a < b));
      break;
    }
    case OP_ADD: {
      if (Object_is_string(vm_stack_peek(vm, 0)) && Object_is_string(vm_stack_peek(vm, 1))) {
        vm_concatenate(vm);
      } else if (Value_is_number(vm_stack_peek(vm, 0)) && Value_is_number(vm_stack_peek(vm, 1))) {
        double b = Value_as_number(vm_stack_pop(vm));
        double a = Value_as_number(vm_stack_pop(vm));
        vm_stack_push(vm, Value_make_number(a + b));
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
      double b = Value_as_number(vm_stack_pop(vm));
      double a = Value_as_number(vm_stack_pop(vm));
      vm_stack_push(vm, Value_make_number(a - b));
      break;
    }
    case OP_MULTIPLY: {
      if (!Value_is_number(vm_stack_peek(vm, 0)) || !Value_is_number(vm_stack_peek(vm, 1))) {
        vm_runtime_error(vm, "Operands must be numbers.");
        return INTERPRET_RUNTIME_ERROR;
      }
      double b = Value_as_number(vm_stack_pop(vm));
      double a = Value_as_number(vm_stack_pop(vm));
      vm_stack_push(vm, Value_make_number(a * b));
      break;
    }
    case OP_DIVIDE: {
      if (!Value_is_number(vm_stack_peek(vm, 0)) || !Value_is_number(vm_stack_peek(vm, 1))) {
        vm_runtime_error(vm, "Operands must be numbers.");
        return INTERPRET_RUNTIME_ERROR;
      }
      double b = Value_as_number(vm_stack_pop(vm));
      double a = Value_as_number(vm_stack_pop(vm));
      vm_stack_push(vm, Value_make_number(a / b));
      break;
    }
    case OP_NOT:
      vm_stack_push(vm, Value_make_boolean(vm_is_falsey(vm_stack_pop(vm))));
      break;
    case OP_NEGATE:
      if (!Value_is_number(vm_stack_peek(vm, 0))) {
        vm_runtime_error(vm, "Operand must be a number.");
        return INTERPRET_RUNTIME_ERROR;
      }
      vm_stack_push(vm, Value_make_number(-Value_as_number(vm_stack_pop(vm))));
      break;
    case OP_PRINT: {
      Value_print(vm_stack_pop(vm));
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
      ObjClosure* closure = Object_allocate_new_closure(&vm->memory_allocator, function);
      vm_stack_push(vm, Value_make_obj((Obj*)closure));
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
    case OP_CLOSE_UPVALUE: {
      vm_close_upvalues(vm, vm->stack_top - 1);
      vm_stack_pop(vm);
      break;
    }
    case OP_RETURN: {
      Value result = vm_stack_pop(vm);
      vm_close_upvalues(vm, call_frame->slots);
      vm->frame_count--;
      if (vm->frame_count == 0) {
        vm_stack_pop(vm);
        return INTERPRET_OK;
      }

      vm->stack_top = call_frame->slots;
      vm_stack_push(vm, result);
      break;
    }
    default:
      return INTERPRET_RUNTIME_ERROR;
  }
  return INTERPRET_INCOMPLETE;
}

static InterpretResult vm_run(Vm* vm) {
  for (;;) {
    InterpretResult result = vm_run_instruction(vm);
    if (result != INTERPRET_INCOMPLETE) {
      return result;
    }
  }
}

static Value vm_stack_peek(Vm* vm, int distance) {
  return vm->stack_top[-1 - distance];
}

static bool vm_is_falsey(Value value) {
  return Value_is_nil(value) || (Value_is_boolean(value) && !Value_as_boolean(value));
}

static bool vm_call(Vm* vm, ObjClosure* closure, int arg_count) {
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
  frame->slots = vm->stack_top - arg_count - 1;
  return true;
}

static bool vm_call_value(Vm* vm, Value callee, int arg_count) {
  if (Value_is_obj(callee)) {
    switch (Object_type(callee)) {
      case OBJ_CLOSURE:
        return vm_call(vm, Object_as_closure(callee), arg_count);
      case OBJ_NATIVE: {
        NativeFn native = Object_as_native(callee);
        Value result = native(arg_count, vm->stack_top - arg_count);
        vm->stack_top -= arg_count + 1;
        vm_stack_push(vm, result);
        return true;
      }
      default:
        break;
    }
  }
  vm_runtime_error(vm, "Can only call functions and classes.");
  return false;
}

static void vm_runtime_error(Vm* vm, const char* format, ...) {
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

static void vm_concatenate(Vm* vm) {
  ObjString* b = Object_as_string(vm_stack_peek(vm, 0));
  ObjString* a = Object_as_string(vm_stack_peek(vm, 1));

  int length = a->length + b->length;
  char* chars = MemoryAllocator_allocate_chars(&vm->memory_allocator, length + 1);
  memcpy(chars, a->chars, a->length);
  memcpy(chars + a->length, b->chars, b->length);
  chars[length] = '\0';

  ObjString* result = Vm_take_string(vm, chars, length);
  vm_stack_pop(vm);
  vm_stack_pop(vm);
  vm_stack_push(vm, Value_make_obj((Obj*)result));
}

static void vm_define_native(Vm* vm, char* name, NativeFn function) {
  vm_stack_push(vm, Value_make_obj((Obj*)Vm_copy_string(vm, name, (int)strlen(name))));
  vm_stack_push(vm, Value_make_obj((Obj*)Object_allocate_new_native(&vm->memory_allocator, function)));
  Table_set(&vm->globals, Object_as_string(vm_stack_peek(vm, 1)), vm_stack_peek(vm, 0));
  vm_stack_pop(vm);
  vm_stack_pop(vm);
}

static ObjUpvalue* vm_capture_upvalue(Vm* vm, Value* local) {
  ObjUpvalue* previous_upvalue = NULL;
  ObjUpvalue* upvalue = vm->open_upvalues;
  while (upvalue != NULL && upvalue->location > local) {
    previous_upvalue = upvalue;
    upvalue = upvalue->next;
  }
  if (upvalue != NULL && upvalue->location == local) {
    return upvalue;
  }

  ObjUpvalue* created_upvalue = Object_allocate_new_upvalue(&vm->memory_allocator, local);
  created_upvalue->next = upvalue;

  if (previous_upvalue == NULL) {
    vm->open_upvalues = created_upvalue;
  } else {
    previous_upvalue->next = created_upvalue;
  }

  return created_upvalue;
}

static void vm_close_upvalues(Vm* vm, Value* last) {
  while (vm->open_upvalues != NULL && vm->open_upvalues->location >= last) {
    ObjUpvalue* upvalue = vm->open_upvalues;
    upvalue->closed = *upvalue->location;
    upvalue->location = &upvalue->closed;
    vm->open_upvalues = upvalue->next;
  }
}

static ObjString* vm_allocate_string(Vm* vm, char* chars, int length, uint32_t hash) {
  ObjString* string = Object_allocate_string(&vm->memory_allocator, chars, length, hash);
  vm->memory_allocator.protected_object = (Obj*)string;
  Table_set(&vm->strings, string, Value_make_nil());
  vm->memory_allocator.protected_object = NULL;
  return string;
}
