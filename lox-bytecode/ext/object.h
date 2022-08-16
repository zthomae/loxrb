#ifndef clox_object_h
#define clox_object_h

#include "common.h"
#include "object_types.h"
#include "chunk.h"
#include "value.h"

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

void Object_print(Value value);

#endif
