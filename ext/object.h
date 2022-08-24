#ifndef clox_object_h
#define clox_object_h

#include "common.h"
#include "object_types.h"
#include "memory_allocator.h"
#include "chunk.h"
#include "value.h"
#include "table.h"

struct ObjString {
  Obj obj;
  int length;
  char* chars;
  uint32_t hash;
};

struct ObjFunction {
  Obj obj;
  int arity;
  int upvalue_count;
  Chunk chunk;
  ObjString* name;
};

typedef Value (*NativeFn)(int arg_count, Value* args);

struct ObjNative {
  Obj obj;
  NativeFn function;
};

struct ObjUpvalue {
  Obj obj;
  Value* location;
  Value closed;
  struct ObjUpvalue* next;
};

struct ObjClosure {
  Obj obj;
  ObjFunction* function;
  ObjUpvalue** upvalues;
  int upvalue_count;
};

struct ObjClass {
  Obj obj;
  ObjString* name;
  Table methods;
};

struct ObjInstance {
  Obj obj;
  ObjClass* klass;
  Table fields;
};

struct ObjBoundMethod {
  Obj obj;
  Value receiver;
  ObjClosure* method;
};

inline ObjType Object_type(Value value) {
  return Value_as_obj(value)->type;
}

inline bool Object_is_type(Value value, ObjType type) {
  return Value_is_obj(value) && Value_as_obj(value)->type == type;
}

inline bool Object_is_function(Value value) {
  return Object_is_type(value, OBJ_FUNCTION);
}

inline bool Object_is_native(Value value) {
  return Object_is_type(value, OBJ_NATIVE);
}

inline bool Object_is_string(Value value) {
  return Object_is_type(value, OBJ_STRING);
}

inline bool Object_is_closure(Value value) {
  return Object_is_type(value, OBJ_CLOSURE);
}

inline bool Object_is_class(Value value) {
  return Object_is_type(value, OBJ_CLASS);
}

inline bool Object_is_instance(Value value) {
  return Object_is_type(value, OBJ_INSTANCE);
}

inline bool Object_is_bound_method(Value value) {
  return Object_is_type(value, OBJ_BOUND_METHOD);
}

inline ObjFunction* Object_as_function(Value value) {
  return (ObjFunction*)Value_as_obj(value);
}

inline NativeFn Object_as_native(Value value) {
  ObjNative* native = (ObjNative*)Value_as_obj(value);
  return native->function;
}

inline ObjString* Object_as_string(Value value) {
  return (ObjString*)Value_as_obj(value);
}

inline char* Object_as_cstring(Value value) {
  return Object_as_string(value)->chars;
}

inline ObjClosure* Object_as_closure(Value value) {
  return (ObjClosure*)Value_as_obj(value);
}

inline ObjClass* Object_as_class(Value value) {
  return (ObjClass*)Value_as_obj(value);
}

inline ObjInstance* Object_as_instance(Value value) {
  return (ObjInstance*)Value_as_obj(value);
}

inline ObjBoundMethod* Object_as_bound_method(Value value) {
  return (ObjBoundMethod*)Value_as_obj(value);
}

void Object_print(Value value);

ObjString* Object_allocate_string(MemoryAllocator* memory_allocator, char* chars, int length, uint32_t hash);
ObjString* Object_allocate_new_string(MemoryAllocator* memory_allocator);
ObjFunction* Object_allocate_new_function(MemoryAllocator* memory_allocator);
ObjNative* Object_allocate_new_native(MemoryAllocator* memory_allocator, NativeFn function);
ObjClosure* Object_allocate_new_closure(MemoryAllocator* memory_allocator, ObjFunction* function);
ObjUpvalue* Object_allocate_new_upvalue(MemoryAllocator* memory_allocator, Value* local);
ObjClass* Object_allocate_new_class(MemoryAllocator* memory_allocator, ObjString* name);
ObjInstance* Object_allocate_new_instance(MemoryAllocator* memory_allocator, ObjClass* klass);
ObjBoundMethod* Object_allocate_new_bound_method(MemoryAllocator* memory_allocator, Value receiver, ObjClosure* method);

void Object_free(MemoryAllocator* memory_allocator, Obj* object);

#endif
