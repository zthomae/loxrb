#include <stdio.h>

#include "common.h"
#include "logger.h"
#include "value.h"
#include "object.h"
#include "table.h"
#include "vm.h"
#include "gc.h"

static void gc_mark_roots(Vm* vm);
static void gc_mark_value(Vm* vm, Value value);
static void gc_mark_object(Vm* vm, Obj* object);
static void gc_mark_table(Vm* vm, Table* table);

inline bool gc_logging_enabled(Vm* vm) {
  return vm->memory_allocator.log_gc;
}

void Gc_collect(Vm* vm) {
  bool print_log_messages = gc_logging_enabled(vm);

  if (print_log_messages) {
    Logger_debug("-- start gc --");
  }

  gc_mark_roots(vm);

  if (print_log_messages) {
    Logger_debug("-- end gc --");
  }
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
}

static void gc_mark_value(Vm* vm, Value value) {
  if (Value_is_obj(value)) {
    gc_mark_object(vm, Value_as_obj(value));
  }
}

static void gc_mark_object(Vm* vm, Obj* object) {
  if (object == NULL) {
    return;
  }

  if (gc_logging_enabled(vm)) {
    Logger_debug_begin_line();
    printf("%p mark ", (void*) object);
    // The forced Value construction here points to the quirkiness of the
    // Object_ interface
    Value_print(Value_make_obj(object));
    printf("\n");
  }

  object->is_marked = true;
}

static void gc_mark_table(Vm* vm, Table* table) {
  for (int i = 0; i < table->capacity; i++) {
    Entry* entry = &table->entries[i];
    gc_mark_object(vm, (Obj*)entry->key);
    gc_mark_value(vm, entry->value);
  }
}
