#ifndef clox_object_h
#define clox_object_h

#include "common.h"
#include "value.h"

typedef enum {
  OBJ_STRING,
} ObjType;

// Obj is like a base class for all objects. Specializations must all
// start with an Obj member, because that lets them be cast to Objs
// for things like type checking. This works because padding at the
// front of a struct is illegal.

struct Obj {
  ObjType type;
};

struct ObjString {
  Obj obj;
  int length;
  char* chars;
};

inline ObjType Object_type(Value value) {
  return Value_as_obj(value)->type;
}

inline bool Object_is_type(Value value, ObjType type) {
  return Value_is_obj(value) && Value_as_obj(value)->type == type;
}

inline bool Object_is_string(Value value) {
  return Object_is_type(value, OBJ_STRING);
}

inline ObjString* Object_as_string(Value value) {
  return (ObjString*)Value_as_obj(value);
}

inline char* Object_as_cstring(Value value) {
  return Object_as_string(value)->chars;
}

ObjString* Object_copy_string(const char* chars, int length);

void Object_print(Value value);

#endif
