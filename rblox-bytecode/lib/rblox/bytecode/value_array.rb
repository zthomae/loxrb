require "ffi"

module Rblox
  module Bytecode
    class ValueArray < FFI::Struct
      layout :capacity, :int, :count, :int, :values, :pointer

      def constant_at(offset)
        (self[:values] + (offset * FFI.type_size(FFI::TYPE_FLOAT64))).read(:double)
      end
    end
  end
end
