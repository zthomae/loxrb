# frozen_string_literal: true

require "ffi"

require_relative "bytecode/compiler"
require_relative "bytecode/interpreter"
require_relative "bytecode/main"
require_relative "bytecode/repl"
require_relative "bytecode/disassembler"
require_relative "bytecode/version"

module Rblox
  module Bytecode
    extend FFI::Library

    ffi_lib File.join(File.dirname(__FILE__), "../../ext/vm.so")

    ### VALUES ###

    class ValueArray < FFI::Struct
      layout :capacity, :int, :count, :int, :values, :pointer

      def constant_at(offset)
        (self[:values] + (offset * FFI.type_size(FFI::TYPE_FLOAT64))).read(:double)
      end
    end

    attach_function :value_print, :Value_print, [:double], :void

    ### CHUNKS ###

    Opcode = enum :opcode, [:constant, :add, :subtract, :multiply, :divide, :negate, :return]

    class Chunk < FFI::Struct
      layout :capacity, :int, :count, :int, :code, :pointer, :lines, :pointer, :constants, ValueArray

      def self.with_new
        FFI::MemoryPointer.new(Rblox::Bytecode::Chunk, 1) do |p|
          chunk = Rblox::Bytecode::Chunk.new(p[0])
          Rblox::Bytecode.chunk_init(chunk)
          begin
            yield chunk
          ensure
            Rblox::Bytecode.chunk_free(chunk)
          end
        end
      end

      def line_at(offset)
        (self[:lines] + (offset * FFI.type_size(FFI::TYPE_INT32))).read(:int)
      end

      def contents_at(offset)
        (self[:code] + (offset * FFI.type_size(FFI::TYPE_UINT8))).read(:uint8)
      end

      def constant_at(offset)
        self[:constants].constant_at(offset)
      end
    end

    attach_function :chunk_init, :Chunk_init, [Chunk.ptr], :void
    attach_function :chunk_write, :Chunk_write, [Chunk.ptr, :uint8, :int], :void
    attach_function :chunk_free, :Chunk_free, [Chunk.ptr], :void
    attach_function :chunk_add_constant, :Chunk_add_constant, [Chunk.ptr, :double], :int

    ### VM ###

    InterpretResult = enum :interpret_result, [:incomplete, :ok, :compile_error, :runtime_error]

    class VM < FFI::Struct
      layout :chunk, Chunk.ptr, :ip, :pointer, :stack, [:double, 256], :stack_top, :pointer

      def self.with_new
        FFI::MemoryPointer.new(Rblox::Bytecode::VM, 1) do |p|
          vm = Rblox::Bytecode::VM.new(p[0])
          Rblox::Bytecode.vm_init(vm)
          begin
            yield vm
          ensure
            Rblox::Bytecode.vm_free(vm)
          end
        end
      end

      def current_offset
        self[:ip].to_i - self[:chunk][:code].to_i
      end

      def stack_contents
        num_elements = (self[:stack_top].address - self[:stack].to_ptr.address) / FFI.type_size(FFI::TYPE_FLOAT64)
        contents = []
        (0...num_elements).each { |i| contents << self[:stack][i] }
        contents
      end
    end

    attach_function :vm_init, :VM_init, [VM.ptr], :void
    attach_function :vm_init_chunk, :VM_init_chunk, [VM.ptr, Chunk.ptr], :void
    attach_function :vm_interpret, :VM_interpret, [VM.ptr, Chunk.ptr], InterpretResult
    attach_function :vm_interpret_next_instruction, :VM_interpret_next_instruction, [VM.ptr], InterpretResult
    attach_function :vm_free, :VM_free, [VM.ptr], :void
  end
end
