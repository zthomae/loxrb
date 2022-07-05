#ifndef clox_value_h
#define clox_value_h

#include "common.h"

typedef double Value;

typedef struct {
  int capacity;
  int count;
  Value* values;
} ValueArray;

void ValueArray_init(ValueArray* array);
void ValueArray_write(ValueArray* array, Value value);
void ValueArray_free(ValueArray* array);

void Value_print(Value value);

#endif
