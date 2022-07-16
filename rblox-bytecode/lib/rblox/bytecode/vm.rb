require "ffi"

module Rblox
  module Bytecode
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
  end
end
