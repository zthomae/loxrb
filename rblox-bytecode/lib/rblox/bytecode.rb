# frozen_string_literal: true

require "ffi"

require_relative "bytecode/value_array"
require_relative "bytecode/chunk"
require_relative "bytecode/vm"
require_relative "bytecode/disassembler"
require_relative "bytecode/version"

module Rblox
  module Bytecode
    extend FFI::Library

    ffi_lib File.join(File.dirname(__FILE__), "../../ext/vm.so")

    Opcode = enum :opcode, [:constant, :return]

    InterpretResult = enum :interpret_result, [:incomplete, :ok, :compile_error, :runtime_error]

    attach_function :chunk_init, :Chunk_init, [Chunk.ptr], :void
    attach_function :chunk_write, :Chunk_write, [Chunk.ptr, :uint8, :int], :void
    attach_function :chunk_free, :Chunk_free, [Chunk.ptr], :void
    attach_function :chunk_add_constant, :Chunk_add_constant, [Chunk.ptr, :double], :int

    attach_function :value_print, :Value_print, [:double], :void

    attach_function :vm_init, :VM_init, [VM.ptr], :void
    attach_function :vm_init_chunk, :VM_init_chunk, [VM.ptr, Chunk.ptr], :void
    attach_function :vm_interpret, :VM_interpret, [VM.ptr, Chunk.ptr], InterpretResult
    attach_function :vm_interpret_next_instruction, :VM_interpret_next_instruction, [VM.ptr], InterpretResult
    attach_function :vm_free, :VM_free, [VM.ptr], :void
  end
end
