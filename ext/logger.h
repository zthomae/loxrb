#ifndef clox_logger_h
#define clox_logger_h

void Logger_debug(const char* format, ...);

inline void Logger_debug_begin_line(void) {
  printf("[DEBUG] ");
}

void Logger_write_multiline_string(const char* string);

#endif
