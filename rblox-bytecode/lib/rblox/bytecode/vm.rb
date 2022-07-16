require "ffi"

module Rblox
  module Bytecode
    class VM < FFI::Struct
      layout :chunk, Chunk.ptr, :ip, :pointer

      def current_offset
        self[:ip].to_i - self[:chunk][:code].to_i
      end
    end
  end
end
