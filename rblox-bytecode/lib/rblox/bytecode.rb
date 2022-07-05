# frozen_string_literal: true

require "ffi"

require_relative "bytecode/value_array"
require_relative "bytecode/chunk"
require_relative "bytecode/disassembler"
require_relative "bytecode/version"

module Rblox
  module Bytecode
    extend FFI::Library

    ffi_lib File.join(File.dirname(__FILE__), "../../ext/vm.so")

    Opcode = enum :opcode, [:constant, :return]

    attach_function :chunk_init, :Chunk_init, [Chunk.ptr], :void
    attach_function :chunk_write, :Chunk_write, [Chunk.ptr, :uint8, :int], :void
    attach_function :chunk_free, :Chunk_free, [Chunk.ptr], :void
    attach_function :chunk_add_constant, :Chunk_add_constant, [Chunk.ptr, :double], :int

    attach_function :value_print, :Value_print, [:double], :void
  end
end
