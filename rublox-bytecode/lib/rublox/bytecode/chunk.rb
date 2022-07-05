require "ffi"

module Rublox
  module Bytecode
    class Chunk < FFI::Struct
      layout :capacity, :int, :count, :int, :code, :pointer, :lines, :pointer, :constants, ValueArray

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
  end
end
