require "ffi"

module Rblox
  module Bytecode
    class VM < FFI::Struct
      layout :chunk, Chunk.ptr, :ip, :pointer

      def self.with_new
        FFI::MemoryPointer.new(Rblox::Bytecode::VM, 1) do |p|
          vm = Rblox::Bytecode::VM.new(p[0])
          Rblox::Bytecode::vm_init(vm)
          begin
            yield vm
          ensure
            Rblox::Bytecode::vm_free(vm)
          end
        end
      end

      def current_offset
        self[:ip].to_i - self[:chunk][:code].to_i
      end
    end
  end
end
