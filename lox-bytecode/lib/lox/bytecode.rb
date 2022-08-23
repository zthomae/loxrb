# frozen_string_literal: true

require "ffi"

require_relative "bytecode/compiler"
require_relative "bytecode/interpreter"
require_relative "bytecode/main"
require_relative "bytecode/repl"
require_relative "bytecode/disassembler"
require_relative "bytecode/version"

module Lox
  module Bytecode
    extend FFI::Library

    if RUBY_PLATFORM.include?("darwin")
      ffi_lib File.join(File.dirname(__FILE__), "../../ext/vm.bundle")
    else
      ffi_lib File.join(File.dirname(__FILE__), "../../ext/vm.so")
    end

    ### MEMORY ALLOCATOR ###

    class MemoryCallbacks < FFI::Struct
      layout :handle_new_object, :pointer, :collect_garbage, :pointer
    end

    class MemoryAllocator < FFI::Struct
      layout :bytes_allocated, :size_t,
        :next_gc, :size_t,
        :gc_enabled, :bool,
        :log_gc, :bool,
        :stress_gc, :bool,
        :callback_target, :pointer,
        :memory_callbacks, MemoryCallbacks,
        :protected_object, :pointer
    end

    ### VALUES ###

    ValueType = enum :value_type, [:bool, :nil, :number, :obj]

    ObjType = enum :obj_type, [:bound_method, :class, :closure, :function, :instance, :native, :string, :upvalue]

    class Obj < FFI::Struct
      layout :type, ObjType, :next, Obj.ptr, :is_marked, :bool

      def as_closure
        ObjClosure.new(self.to_ptr)
      end

      def as_function
        ObjFunction.new(self.to_ptr)
      end

      def as_string
        ObjString.new(self.to_ptr)
      end

      def as_class
        ObjClass.new(self.to_ptr)
      end

      def as_instance
        ObjInstance.new(self.to_ptr)
      end

      def as_bound_method
        ObjBoundMethod.new(self.to_ptr)
      end

      def to_s
        case self[:type]
        when :closure
          function_name = self.as_closure[:function][:name][:chars]
          if function_name
            "<fn #{function_name}>"
          else
            "<script>"
          end
        when :function
          function_name = self.as_function[:name][:chars]
          if function_name
            "<fn #{function_name}>"
          else
            "<script>"
          end
        when :native
          "<native fn>"
        when :string
          self.as_string[:chars]
        when :class
          self.as_class[:name][:chars]
        when :instance
          self.as_instance[:klass][:name][:chars]
        when :bound_method
          self.as_bound_method[:method].to_s
        else
          raise "Unsupported object type #{self[:type]}"
        end
      end
    end

    class ValueU < FFI::Union
      layout :boolean, :bool, :number, :double, :obj, Obj.ptr
    end

    class Value < FFI::Struct
      layout :type, ValueType, :as, ValueU

      def to_s
        case self[:type]
        when :bool
          self[:as][:boolean].to_s
        when :nil
          "nil"
        when :number
          self[:as][:number].to_s
        when :obj
          self[:as][:obj].to_s
        else
          raise "Unsupported value type #{self[:type]}"
        end
      end
    end

    attach_function :value_print, :Value_print, [Value], :void

    class ValueArray < FFI::Struct
      layout :capacity, :int, :count, :int, :values, :pointer, :memory_allocator, MemoryAllocator.ptr

      def constant_at(offset)
        Value.new(self[:values] + (offset * Value.size))
      end
    end

    class ObjString < FFI::Struct
      layout :obj, Obj, :length, :int, :chars, :string, :hash, :uint32
    end

    ### TABLE ###

    class Entry < FFI::Struct
      layout :key, ObjString.ptr, :value, Value
    end

    class Table < FFI::Struct
      layout :count, :int, :capacity, :int, :entries, Entry.ptr, :memory_allocator, MemoryAllocator.ptr
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
      :get_upvalue,
      :set_upvalue,
      :get_property,
      :set_property,
      :get_super,
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
      :call,
      :invoke,
      :super_invoke,
      :closure,
      :close_upvalue,
      :return,
      :class,
      :inherit,
      :method
    ]

    class Chunk < FFI::Struct
      layout :capacity, :int, :count, :int, :code, :pointer, :lines, :pointer, :constants, ValueArray, :memory_allocator, MemoryAllocator.ptr

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

    attach_function :chunk_write, :Chunk_write, [Chunk.ptr, :uint8, :int], :void

    attach_function :chunk_add_number, :Chunk_add_number, [Chunk.ptr, :double], :int
    attach_function :chunk_add_object, :Chunk_add_object, [Chunk.ptr, :pointer], :int

    ### FUNCTIONS ###

    class ObjFunction < FFI::Struct
      layout :obj, Obj, :arity, :int, :upvalue_count, :int, :chunk, Chunk, :name, ObjString.ptr
    end

    class ObjClosure < FFI::Struct
      layout :obj, Obj, :function, ObjFunction.ptr, :upvalues, :pointer, :upvalue_count, :int
    end

    class ObjUpvalue < FFI::Struct
      layout :obj, Obj, :location, Value.ptr, :closed, Value, :next, ObjUpvalue.ptr
    end

    ### OOP ###

    class ObjClass < FFI::Struct
      layout :obj, Obj, :name, ObjString.ptr, :methods, Table
    end

    class ObjInstance < FFI::Struct
      layout :obj, Obj, :klass, ObjClass.ptr, :fields, Table
    end

    class ObjBoundMethod < FFI::Struct
      layout :obj, Obj, :receiver, Value, :method, ObjClosure
    end

    ### VM ###

    class CallFrame < FFI::Struct
      layout :closure, ObjClosure.ptr, :ip, :pointer, :slots, Value.ptr
    end

    InterpretResult = enum :interpret_result, [:incomplete, :ok, :compile_error, :runtime_error]

    class VM < FFI::Struct
      layout :frames, [CallFrame, 64],
        :frame_count, :int,
        :stack, [Value, 64 * 256],
        :stack_top, Value.ptr,
        :globals, Table,
        :open_upvalues, ObjUpvalue.ptr,
        :objects, Obj.ptr,
        :strings, Table,
        :memory_allocator, MemoryAllocator,
        :gray_count, :int,
        :gray_capacity, :int,
        :gray_stack, :pointer

      def with_new_function
        yield Lox::Bytecode.vm_new_function(self)
      end

      def current_frame
        self[:frames][self[:frame_count] - 1]
      end

      def current_function
        current_frame[:closure][:function]
      end

      def current_offset
        current_frame[:ip].to_i - current_function[:chunk][:code].to_i
      end

      def stack_contents
        num_elements = (self[:stack_top].to_ptr.address - self[:stack].to_ptr.address) / Value.size
        contents = []
        (0...num_elements).each { |i| contents << self[:stack][i].to_s }
        contents
      end
    end

    attach_function :vm_init, :Vm_init, [VM.ptr], :void
    attach_function :vm_init_function, :Vm_init_function, [VM.ptr, ObjFunction.ptr], :void
    attach_function :vm_interpret, :Vm_interpret, [VM.ptr, ObjFunction.ptr], InterpretResult
    attach_function :vm_interpret_next_instruction, :Vm_interpret_next_instruction, [VM.ptr], InterpretResult
    attach_function :vm_new_function, :Vm_new_function, [VM.ptr], ObjFunction.ptr
    attach_function :vm_copy_string, :Vm_copy_string, [VM.ptr, :pointer, :int], ObjString.ptr
    attach_function :vm_free, :Vm_free, [VM.ptr], :void
  end
end
