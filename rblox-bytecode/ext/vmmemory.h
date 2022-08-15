#ifndef clox_vmmemory_h
#define clox_vmmemory_h

#include "common.h"
#include "vm.h"

ObjString* VmMemory_allocate_string(VM* vm, char* chars, int length, uint32_t hash);
ObjString* VmMemory_allocate_new_string(VM* vm);
ObjFunction* VmMemory_allocate_new_function(VM* vm);
ObjNative* VmMemory_allocate_new_native(VM* vm, NativeFn function);
ObjClosure* VmMemory_allocate_new_closure(VM* vm, ObjFunction* function);
ObjUpvalue* VmMemory_allocate_new_upvalue(VM* vm, Value* local);

ObjString* VmMemory_copy_string(VM* vm, char* chars, int length);
ObjString* VmMemory_take_string(VM* vm, char* chars, int length);

void VmMemory_free_objects(VM* vm);

#endif
