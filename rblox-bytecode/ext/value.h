#ifndef clox_value_h
#define clox_value_h

#include "common.h"

typedef enum {
  VAL_BOOL,
  VAL_NIL,
  VAL_NUMBER,
} ValueType;

typedef struct {
  ValueType type;
  union {
    bool boolean;
    double number;
  } as;
} Value;

typedef struct {
  int capacity;
  int count;
  Value* values;
} ValueArray;

void ValueArray_init(ValueArray* array);
void ValueArray_write(ValueArray* array, Value value);
void ValueArray_free(ValueArray* array);

void Value_print(Value value);

inline Value Value_make_boolean(bool value) {
  return (Value){VAL_BOOL, {.boolean = value}};
}

inline Value Value_make_nil() {
  return (Value){VAL_NIL, {.number = 0}};
}

inline Value Value_make_number(double value) {
  return (Value){VAL_NUMBER, {.number = value}};
}

inline bool Value_as_boolean(Value value) {
  return value.as.boolean;
}

inline double Value_as_number(Value value) {
  return value.as.number;
}

inline bool Value_is_boolean(Value value) {
  return value.type == VAL_BOOL;
}

inline bool Value_is_nil(Value value) {
  return value.type == VAL_NIL;
}

inline bool Value_is_number(Value value) {
  return value.type == VAL_NUMBER;
}

#endif
