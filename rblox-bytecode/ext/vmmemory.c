#include <string.h>

#include "object.h"
#include "vm.h"
#include "memory.h"
#include "vmmemory.h"

static uint32_t vmmemory_hash_string(char* chars, int length);

ObjString* VmMemory_allocate_string(VM* vm, char* chars, int length, uint32_t hash) {
  ObjString* string = VmMemory_allocate_new_string(vm);
  string->length = length;
  string->chars = chars;
  string->hash = hash;
  Table_set(&vm->strings, string, Value_make_nil());
  return string;
}

Obj* vm_allocate_new(VM* vm, size_t size, ObjType type) {
  Obj* object = (Obj*)Memory_reallocate(NULL, 0, size);
  object->type = type;

  object->next = vm->objects;
  vm->objects = object;

  return object;
}

ObjString* VmMemory_allocate_new_string(VM* vm) {
  return (ObjString*)vm_allocate_new(vm, sizeof(ObjString), OBJ_STRING);
}

ObjUpvalue* VmMemory_allocate_new_upvalue(VM* vm, Value* slot) {
  ObjUpvalue* upvalue = (ObjUpvalue*)vm_allocate_new(vm, sizeof(ObjUpvalue), OBJ_UPVALUE);
  upvalue->location = slot;
  upvalue->closed = Value_make_nil();
  upvalue->next = NULL;
  return upvalue;
}

ObjFunction* VmMemory_allocate_new_function(VM* vm) {
  return (ObjFunction*)vm_allocate_new(vm, sizeof(ObjFunction), OBJ_FUNCTION);
}

ObjNative* VmMemory_allocate_new_native(VM* vm, NativeFn function) {
  ObjNative* native = (ObjNative*)vm_allocate_new(vm, sizeof(ObjNative), OBJ_NATIVE);
  native->function = function;
  return native;
}

ObjClosure* VmMemory_allocate_new_closure(VM* vm, ObjFunction* function) {
  ObjUpvalue** upvalues = Memory_allocate(sizeof(ObjUpvalue*), function->upvalue_count);
  for (int i = 0; i < function->upvalue_count; i++) {
    upvalues[i] = NULL;
  }
  ObjClosure* closure = (ObjClosure*)vm_allocate_new(vm, sizeof(ObjClosure), OBJ_CLOSURE);
  closure->function = function;
  closure->upvalues = upvalues;
  closure->upvalue_count = function->upvalue_count;
  return closure;
}

ObjString* VmMemory_copy_string(VM* vm, char* chars, int length) {
  uint32_t hash = vmmemory_hash_string(chars, length);
  ObjString* interned = Table_find_string(&vm->strings, chars, length, hash);
  if (interned != NULL) {
    return interned;
  }

  char* heap_chars = Memory_allocate_chars(length + 1);
  memcpy(heap_chars, chars, length);
  heap_chars[length] = '\0';
  return VmMemory_allocate_string(vm, heap_chars, length, hash);
}

ObjString* VmMemory_take_string(VM* vm, char* chars, int length) {
  uint32_t hash = vmmemory_hash_string(chars, length);
  ObjString* interned = Table_find_string(&vm->strings, chars, length, hash);
  if (interned != NULL) {
    Memory_free_array(chars, sizeof(char), length + 1);
    return interned;
  }

  return VmMemory_allocate_string(vm, chars, length, hash);
}

void VmMemory_free_objects(VM* vm) {
  Obj* object = vm->objects;
  while (object != NULL) {
    Obj* next = object->next;
    Memory_free_object(object);
    object = next;
  }
}

static uint32_t vmmemory_hash_string(char* key, int length) {
  uint32_t hash = 2166136261u;
  for (int i = 0; i < length; i++) {
    hash ^= (uint8_t)key[i];
    hash *= 16777619;
  }
  return hash;
}
