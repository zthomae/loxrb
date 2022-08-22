#include <stdlib.h>
#include <stdio.h>

#include "common.h"
#include "logger.h"
#include "value.h"
#include "object.h"
#include "table.h"
#include "vm.h"
#include "gc.h"

static void gc_mark_protected_objects(Vm* vm);
static void gc_mark_roots(Vm* vm);
static void gc_mark_value(Vm* vm, Value value);
static void gc_mark_object(Vm* vm, Obj* object);
static void gc_mark_table(Vm* vm, Table* table);
static void gc_mark_array(Vm* vm, ValueArray* array);

static void gc_trace_references(Vm* vm);
static void gc_blacken_object(Vm* vm, Obj* object);

static void gc_remove_white_entries(Table* table);

static void gc_sweep(Vm* vm);

static void gc_log_value(Value value);
static void gc_log_function_name(ObjFunction* function);

inline bool gc_enabled(Vm* vm) {
  return vm->memory_allocator.gc_enabled;
}

inline bool gc_logging_enabled(Vm* vm) {
  return vm->memory_allocator.log_gc;
}

void Gc_collect(Vm* vm) {
  if (!gc_enabled(vm)) {
    return;
  }

  bool print_log_messages = gc_logging_enabled(vm);

  if (print_log_messages) {
    Logger_debug("-- start gc --");
  }
  MemoryAllocator* memory_allocator = &vm->memory_allocator;
  size_t before = memory_allocator->bytes_allocated;

  gc_mark_protected_objects(vm);
  gc_mark_roots(vm);
  gc_trace_references(vm);
  gc_remove_white_entries(&vm->strings);
  gc_sweep(vm);

  memory_allocator->next_gc = memory_allocator->bytes_allocated * memory_allocator->gc_heap_grow_factor;

  if (print_log_messages) {
    Logger_debug("-- end gc --");
    Logger_debug(
      "   collected %zu bytes (from %zu to %zu) next at %zu",
      before - memory_allocator->bytes_allocated,
      before,
      memory_allocator->bytes_allocated,
      memory_allocator->next_gc
    );
  }
}

static void gc_mark_protected_objects(Vm* vm) {
  gc_mark_object(vm, vm->memory_allocator.protected_object);
}

static void gc_mark_roots(Vm* vm) {
  for (Value* slot = vm->stack; slot < vm->stack_top; slot++) {
    gc_mark_value(vm, *slot);
  }

  for (int i = 0; i < vm->frame_count; i++) {
    gc_mark_object(vm, (Obj*)vm->frames[i].closure);
  }

  for (ObjUpvalue* upvalue = vm->open_upvalues; upvalue != NULL; upvalue = upvalue->next) {
    gc_mark_object(vm, (Obj*)upvalue);
  }

  gc_mark_table(vm, &vm->globals);

  gc_mark_object(vm, vm->init_string);
}

static void gc_mark_value(Vm* vm, Value value) {
  if (Value_is_obj(value)) {
    gc_mark_object(vm, Value_as_obj(value));
  }
}

static void gc_mark_object(Vm* vm, Obj* object) {
  if (object == NULL || object->is_marked) {
    return;
  }

  if (gc_logging_enabled(vm)) {
    Logger_debug_begin_line();
    printf("%p mark ", (void*) object);
    // The forced Value construction here points to the quirkiness of the
    // Object_ interface
    gc_log_value(Value_make_obj(object));
    printf("\n");
    fflush(stdout);
  }

  object->is_marked = true;

  if (vm->gray_count + 1 > vm->gray_capacity) {
    vm->gray_capacity = MemoryAllocator_get_increased_capacity(
      &vm->memory_allocator,
      vm->gray_capacity
    );
    vm->gray_stack = (Obj**)realloc(vm->gray_stack, sizeof(Obj*) * vm->gray_capacity);
    if (vm->gray_stack == NULL) {
      exit(1);
    }
  }
  vm->gray_stack[vm->gray_count++] = object;
}

static void gc_mark_table(Vm* vm, Table* table) {
  for (int i = 0; i < table->capacity; i++) {
    Entry* entry = &table->entries[i];
    gc_mark_object(vm, (Obj*)entry->key);
    gc_mark_value(vm, entry->value);
  }
}

static void gc_mark_array(Vm* vm, ValueArray* array) {
  for (int i = 0; i < array->count; i++) {
    gc_mark_value(vm, array->values[i]);
  }
}

static void gc_trace_references(Vm* vm) {
  while (vm->gray_count > 0) {
    Obj* object = vm->gray_stack[--vm->gray_count];
    gc_blacken_object(vm, object);
  }
}

static void gc_blacken_object(Vm* vm, Obj* object) {
  if (gc_logging_enabled(vm)) {
    Logger_debug_begin_line();
    printf("%p blacken ", (void*)object);
    gc_log_value(Value_make_obj(object));
    printf("\n");
    fflush(stdout);
  }

  switch (object->type) {
    case OBJ_NATIVE:
    case OBJ_STRING:
      break;
    case OBJ_UPVALUE:
      gc_mark_value(vm, ((ObjUpvalue*)object)->closed);
      break;
    case OBJ_FUNCTION: {
      ObjFunction* function = (ObjFunction*)object;
      gc_mark_object(vm, (Obj*)function->name);
      gc_mark_array(vm, &function->chunk.constants);
      break;
    }
    case OBJ_CLOSURE: {
      ObjClosure* closure = (ObjClosure*)object;
      gc_mark_object(vm, (Obj*)closure->function);
      for (int i = 0; i < closure->upvalue_count; i++) {
        gc_mark_object(vm, (Obj*)closure->upvalues[i]);
      }
      break;
    }
    case OBJ_CLASS: {
      ObjClass* klass = (ObjClass*)object;
      gc_mark_object(vm, (Obj*)klass->name);
      gc_mark_table(vm, &klass->methods);
      break;
    }
    case OBJ_INSTANCE: {
      ObjInstance* instance = (ObjInstance*)object;
      gc_mark_object(vm, (Obj*)instance->klass);
      gc_mark_table(vm, &instance->fields);
      break;
    }
    case OBJ_BOUND_METHOD: {
      ObjBoundMethod* bound_method = (ObjBoundMethod*)object;
      gc_mark_value(vm, bound_method->receiver);
      gc_mark_object(vm, (Obj*)bound_method->method);
      break;
    }
  }
}

static void gc_remove_white_entries(Table* table) {
  for (int i = 0; i < table->capacity; i++) {
    Entry* entry = &table->entries[i];
    if (entry->key != NULL && !entry->key->obj.is_marked) {
      Table_delete(table, entry->key);
    }
  }
}

static void gc_sweep(Vm* vm) {
  Obj* previous = NULL;
  Obj* object = vm->objects;
  while (object != NULL) {
    if (object->is_marked) {
      object->is_marked = false;
      previous = object;
      object = object->next;
    } else {
      Obj* unreached = object;
      if (object == object->next) {
        fprintf(stderr, "Mid-sweep object cycle!\n");
        exit(1);
      }
      object = object->next;
      if (previous != NULL) {
        previous->next = object;
      } else {
        vm->objects = object;
      }

      Object_free(&vm->memory_allocator, unreached);
    }
  }
}

static void gc_log_value(Value value) {
  switch (Object_type(value)) {
    case OBJ_CLASS:
      printf("%s", Object_as_class(value)->name->chars);
      break;
    case OBJ_CLOSURE:
      gc_log_function_name(Object_as_closure(value)->function);
      break;
    case OBJ_FUNCTION:
      gc_log_function_name(Object_as_function(value));
      break;
    case OBJ_INSTANCE:
      printf("%s instance", Object_as_instance(value)->klass->name->chars);
    case OBJ_NATIVE:
      printf("<native fn>");
      break;
    case OBJ_STRING:
      Logger_write_multiline_string(Object_as_cstring(value));
      break;
    case OBJ_UPVALUE:
      printf("upvalue");
      break;
  }
}

static void gc_log_function_name(ObjFunction* function) {
  if (function->name == NULL) {
    printf("<script>");
  } else {
    Logger_write_multiline_string(function->name->chars);
  }
}
