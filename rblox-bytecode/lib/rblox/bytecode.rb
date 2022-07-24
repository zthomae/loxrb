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

    ValueType = enum :value_type, [:bool, :nil, :number, :obj]

    ObjType = enum :obj_type, [:function, :string]

    class Obj < FFI::Struct
      layout :type, ObjType, :next, Obj.ptr

      def as_function
        ObjFunction.new(self.to_ptr)
      end

      def as_string
        ObjString.new(self.to_ptr)
      end
    end

    class ValueU < FFI::Union
      layout :boolean, :bool, :number, :double, :obj, Obj.ptr
    end

    class Value < FFI::Struct
      layout :type, ValueType, :as, ValueU

      def value
        case self[:type]
        when :bool
          self[:as][:boolean]
        when :nil
          nil
        when :number
          self[:as][:number]
        when :obj
          obj = self[:as][:obj]
          case obj[:type]
          when :function
            "<fn #{obj.as_function[:name][:chars]}>"
          when :string
            obj.as_string[:chars]
          else
            raise "Unsupported object type #{obj[:type]}"
          end
        else
          raise "Unsupported value type #{self[:type]}"
        end
      end
    end

    class ValueArray < FFI::Struct
      layout :capacity, :int, :count, :int, :values, :pointer

      def constant_at(offset)
        value = Value.new(self[:values] + (offset * Value.size))
        case value[:type]
        when :number
          value[:as][:number]
        when :obj
          value[:as][:obj]
        else
          raise "Unsupported value type #{value[:type]}"
        end
      end
    end

    attach_function :value_print, :Value_print, [Value], :void

    class ObjString < FFI::Struct
      layout :obj, Obj, :length, :int, :chars, :string, :hash, :uint32
    end

    ### TABLE ###

    class Entry < FFI::Struct
      layout :key, ObjString.ptr, :value, Value
    end

    class Table < FFI::Struct
      layout :count, :int, :capacity, :int, :entries, Entry.ptr
    end

    ### CHUNKS ###

    Opcode = enum :opcode, [
      :constant,
      :nil,
      :true,
      :false,
      :pop,
      :get_local,
      :set_local,
      :get_global,
      :define_global,
      :set_global,
      :equal,
      :greater,
      :less,
      :add,
      :subtract,
      :multiply,
      :divide,
      :not,
      :negate,
      :print,
      :jump,
      :jump_if_false,
      :loop,
      :return
    ]

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

      def patch_contents_at(offset, value)
        (self[:code] + (offset * FFI.type_size(FFI::TYPE_UINT8))).write(:uint8, value)
      end

      def constant_at(offset)
        self[:constants].constant_at(offset)
      end
    end

    attach_function :chunk_init, :Chunk_init, [Chunk.ptr], :void
    attach_function :chunk_write, :Chunk_write, [Chunk.ptr, :uint8, :int], :void
    attach_function :chunk_free, :Chunk_free, [Chunk.ptr], :void

    attach_function :chunk_add_number, :Chunk_add_number, [Chunk.ptr, :double], :int
    attach_function :chunk_add_object, :Chunk_add_object, [Chunk.ptr, :pointer], :int

    ### FUNCTIONS ###

    class ObjFunction < FFI::Struct
      layout :obj, Obj, :arity, :int, :chunk, Chunk, :name, ObjString.ptr
    end

    ### VM ###

    class CallFrame < FFI::Struct
      layout :function, ObjFunction.ptr, :ip, :pointer, :slots, Value.ptr
    end

    InterpretResult = enum :interpret_result, [:incomplete, :ok, :compile_error, :runtime_error]

    class VM < FFI::Struct
      layout :frames, [CallFrame, 64],
        :frame_count, :int,
        :stack, [Value, 64 * 256],
        :stack_top, Value.ptr,
        :globals, Table,
        :strings, Table,
        :objects, Obj.ptr

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

      def with_new_function
        begin
          function = Rblox::Bytecode.vm_new_function(self)
          yield function
        ensure
          if function
            Rblox::Bytecode.memory_free_object(Rblox::Bytecode::Obj.new(function.to_ptr))
          end
        end
      end

      def current_frame
        self[:frames][self[:frame_count] - 1]
      end

      def current_function
        current_frame[:function]
      end

      def current_offset
        current_frame[:ip].to_i - current_function[:chunk][:code].to_i
      end

      def stack_contents
        num_elements = (self[:stack_top].to_ptr.address - self[:stack].to_ptr.address) / Value.size
        contents = []
        (0...num_elements).each { |i| contents << self[:stack][i].value }
        contents
      end
    end

    attach_function :vm_init, :VM_init, [VM.ptr], :void
    attach_function :vm_init_function, :VM_init_function, [VM.ptr, ObjFunction.ptr], :void
    attach_function :vm_interpret, :VM_interpret, [VM.ptr, ObjFunction.ptr], InterpretResult
    attach_function :vm_interpret_next_instruction, :VM_interpret_next_instruction, [VM.ptr], InterpretResult
    attach_function :vm_copy_string, :VM_copy_string, [VM.ptr, :pointer, :int], ObjString.ptr
    attach_function :vm_new_function, :VM_new_function, [VM.ptr], ObjFunction.ptr
    attach_function :vm_free, :VM_free, [VM.ptr], :void

    attach_function :memory_free_object, :Memory_free_object, [Obj.ptr], :void
  end
end
