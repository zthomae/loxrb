#ifndef clox_logger_h
#define clox_logger_h

void Logger_debug(const char* format, ...);

inline void Logger_debug_begin_line(void) {
  printf("[DEBUG] ");
}

#endif
