#include "common.h"
#include "logger.h"
#include "vm.h"
#include "gc.h"

void Gc_collect(Vm* vm) {
  bool print_log_messages = vm->memory_allocator.log_gc;

  if (print_log_messages) {
    Logger_debug("-- start gc --");
  }

  if (print_log_messages) {
    Logger_debug("-- end gc --");
  }
}
