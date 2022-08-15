#ifndef clox_vmmemory_h
#define clox_vmmemory_h

#include "common.h"
#include "vm.h"

ObjString* VmMemory_allocate_string(Vm* vm, char* chars, int length, uint32_t hash);
ObjString* VmMemory_allocate_new_string(Vm* vm);
ObjFunction* VmMemory_allocate_new_function(Vm* vm);
ObjNative* VmMemory_allocate_new_native(Vm* vm, NativeFn function);
ObjClosure* VmMemory_allocate_new_closure(Vm* vm, ObjFunction* function);
ObjUpvalue* VmMemory_allocate_new_upvalue(Vm* vm, Value* local);

ObjString* VmMemory_copy_string(Vm* vm, char* chars, int length);
ObjString* VmMemory_take_string(Vm* vm, char* chars, int length);

void VmMemory_free_objects(Vm* vm);

#endif
