#ifndef clox_object_types_h
#define clox_object_types_h

#include "common.h"

// This file is broken out from object.h to avoid circular dependencies

typedef enum {
  OBJ_CLASS,
  OBJ_CLOSURE,
  OBJ_FUNCTION,
  OBJ_INSTANCE,
  OBJ_NATIVE,
  OBJ_STRING,
  OBJ_UPVALUE,
} ObjType;

// Obj is like a base class for all objects. Specializations must all
// start with an Obj member, because that lets them be cast to Objs
// for things like type checking. This works because padding at the
// front of a struct is illegal.

struct Obj {
  ObjType type;
  struct Obj* next;
  bool is_marked;
};
typedef struct Obj Obj;

typedef struct ObjString ObjString;
typedef struct ObjFunction ObjFunction;
typedef struct ObjNative ObjNative;
typedef struct ObjUpvalue ObjUpvalue;
typedef struct ObjClosure ObjClosure;
typedef struct ObjClass ObjClass;
typedef struct ObjInstance ObjInstance;

#endif
