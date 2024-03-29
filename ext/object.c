#include <stdio.h>

#include "memory_allocator.h"
#include "logger.h"
#include "object.h"
#include "value.h"
#include "table.h"

Obj* object_allocate_new(MemoryAllocator* memory_allocator, size_t size, ObjType type);
static void object_print_function(ObjFunction* function);

void Object_print(Value value) {
  switch (Object_type(value)) {
    case OBJ_BOUND_METHOD:
      object_print_function(Object_as_bound_method(value)->method->function);
      break;
    case OBJ_CLASS:
      printf("%s", Object_as_class(value)->name->chars);
      break;
    case OBJ_CLOSURE:
      object_print_function(Object_as_closure(value)->function);
      break;
    case OBJ_FUNCTION:
      object_print_function(Object_as_function(value));
      break;
    case OBJ_INSTANCE:
      printf("%s instance", Object_as_instance(value)->klass->name->chars);
      break;
    case OBJ_NATIVE:
      printf("<native fn>");
      break;
    case OBJ_STRING:
      printf("%s", Object_as_cstring(value));
      break;
    case OBJ_UPVALUE:
      printf("upvalue");
      break;
  }
}

ObjString* Object_allocate_string(MemoryAllocator* memory_allocator, char* chars, int length, uint32_t hash) {
  ObjString* string = Object_allocate_new_string(memory_allocator);
  string->length = length;
  string->chars = chars;
  string->hash = hash;
  return string;
}

ObjString* Object_allocate_new_string(MemoryAllocator* memory_allocator) {
  return (ObjString*)object_allocate_new(memory_allocator, sizeof(ObjString), OBJ_STRING);
}

ObjUpvalue* Object_allocate_new_upvalue(MemoryAllocator* memory_allocator, Value* slot) {
  ObjUpvalue* upvalue = (ObjUpvalue*)object_allocate_new(memory_allocator, sizeof(ObjUpvalue), OBJ_UPVALUE);
  upvalue->location = slot;
  upvalue->closed = Value_make_nil();
  upvalue->next = NULL;
  return upvalue;
}

ObjFunction* Object_allocate_new_function(MemoryAllocator* memory_allocator) {
  return (ObjFunction*)object_allocate_new(memory_allocator, sizeof(ObjFunction), OBJ_FUNCTION);
}

ObjNative* Object_allocate_new_native(MemoryAllocator* memory_allocator, NativeFn function) {
  ObjNative* native = (ObjNative*)object_allocate_new(memory_allocator, sizeof(ObjNative), OBJ_NATIVE);
  native->function = function;
  return native;
}

ObjClosure* Object_allocate_new_closure(MemoryAllocator* memory_allocator, ObjFunction* function) {
  ObjUpvalue** upvalues = MemoryAllocator_allocate(memory_allocator, sizeof(ObjUpvalue*), function->upvalue_count);
  for (int i = 0; i < function->upvalue_count; i++) {
    upvalues[i] = NULL;
  }
  ObjClosure* closure = (ObjClosure*)object_allocate_new(memory_allocator, sizeof(ObjClosure), OBJ_CLOSURE);
  closure->function = function;
  closure->upvalues = upvalues;
  closure->upvalue_count = function->upvalue_count;
  return closure;
}

ObjClass* Object_allocate_new_class(MemoryAllocator* memory_allocator, ObjString* name) {
  ObjClass* klass = (ObjClass*)object_allocate_new(memory_allocator, sizeof(ObjClass), OBJ_CLASS);
  klass->name = name;
  Table_init(&klass->methods, memory_allocator);
  return klass;
}

ObjInstance* Object_allocate_new_instance(MemoryAllocator* memory_allocator, ObjClass* klass) {
  ObjInstance* instance = (ObjInstance*)object_allocate_new(memory_allocator, sizeof(ObjInstance), OBJ_INSTANCE);
  instance->klass = klass;
  Table_init(&instance->fields, memory_allocator);
  return instance;
}

ObjBoundMethod* Object_allocate_new_bound_method(MemoryAllocator* memory_allocator, Value receiver, ObjClosure* method) {
  ObjBoundMethod* bound_method = (ObjBoundMethod*)object_allocate_new(memory_allocator, sizeof(ObjBoundMethod), OBJ_BOUND_METHOD);
  bound_method->receiver = receiver;
  bound_method->method = method;
  return bound_method;
}

void Object_free(MemoryAllocator* memory_allocator, Obj* object) {
  if (memory_allocator->log_gc) {
    Logger_debug("%p free type %d", (void*)object, object->type);
  }

  switch (object->type) {
    case OBJ_BOUND_METHOD: {
      MemoryAllocator_free(memory_allocator, object, sizeof(ObjBoundMethod));
      break;
    }
    case OBJ_CLASS: {
      ObjClass* klass = (ObjClass*)object;
      Table_free(&klass->methods);
      MemoryAllocator_free(memory_allocator, object, sizeof(ObjClass));
      break;
    }
    case OBJ_CLOSURE: {
      ObjClosure* closure = (ObjClosure*)object;
      // Don't free the upvalues themselves, because the closure doesn't own them
      MemoryAllocator_free_array(memory_allocator, closure->upvalues, sizeof(ObjUpvalue*), closure->upvalue_count);
      // Don't free function, because the closure doesn't own this either
      MemoryAllocator_free(memory_allocator, object, sizeof(ObjClosure));
      break;
    }
    case OBJ_FUNCTION: {
      ObjFunction* function = (ObjFunction*)object;
      Chunk_free(&function->chunk);
      MemoryAllocator_free(memory_allocator, function, sizeof(ObjFunction));
      // function name is an ObjString, so we leave it for the garbage collector
      break;
    }
    case OBJ_INSTANCE: {
      ObjInstance* instance = (ObjInstance*)object;
      Table_free(&instance->fields);
      MemoryAllocator_free(memory_allocator, instance, sizeof(ObjInstance));
      break;
    }
    case OBJ_NATIVE:
      MemoryAllocator_free(memory_allocator, object, sizeof(ObjNative));
      break;
    case OBJ_STRING: {
      ObjString* string = (ObjString*)object;
      MemoryAllocator_free_array(memory_allocator, string->chars, sizeof(char), string->length + 1);
      MemoryAllocator_free(memory_allocator, object, sizeof(ObjString));
      break;
    }
    case OBJ_UPVALUE: {
      MemoryAllocator_free(memory_allocator, object, sizeof(ObjUpvalue));
      break;
    }
  }
}

static void object_print_function(ObjFunction* function) {
  if (function->name == NULL) {
    printf("<script>");
    return;
  }
  printf("<fn %s>", function->name->chars);
}

Obj* object_allocate_new(MemoryAllocator* memory_allocator, size_t size, ObjType type) {
  Obj* object = (Obj*)MemoryAllocator_reallocate(memory_allocator, NULL, 0, size);
  object->type = type;
  object->is_marked = false;

  (*memory_allocator->callbacks.handle_new_object)(memory_allocator->callback_target, object);

  if (memory_allocator->log_gc) {
    Logger_debug("%p allocate %zu for %d", (void*)object, size, type);
  }

  return object;
}
