#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>

#include "logger.h"

void Logger_debug(const char* format, ...) {
  size_t format_string_length = strlen(format);
  char* updated_format_string = malloc(format_string_length + 10);
  memcpy(updated_format_string, "[DEBUG] ", 8);
  memcpy(updated_format_string + 8, format, format_string_length);
  updated_format_string[format_string_length + 8] = '\n';
  updated_format_string[format_string_length + 9] = '\0';

  va_list format_args;
  va_start(format_args, format);
  vfprintf(stdout, updated_format_string, format_args);
  va_end(format_args);

  free(updated_format_string);
}
