#ifndef clox_base_object_h
#define clox_base_object_h

// This file is broken out from object.h to avoid circular dependencies

typedef enum {
  OBJ_CLOSURE,
  OBJ_FUNCTION,
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
};

#endif