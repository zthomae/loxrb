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

  fflush(stdout);
}

void Logger_write_multiline_string(const char* string) {
  size_t string_length = strlen(string);
  char* temp_string = malloc(string_length + 1);
  strcpy(temp_string, string);

  size_t line_start = 0;
  while (line_start < string_length) {
    size_t next_newline = line_start;
    while (next_newline < string_length && string[next_newline] != '\n') {
      next_newline++;
    }
    temp_string[next_newline] = '\0';
    printf("%s", temp_string + line_start);
    line_start = next_newline + 1;
    if (string[next_newline] == '\n') {
      printf("\n[DEBUG] ");
    }
  }

  free(temp_string);
}
