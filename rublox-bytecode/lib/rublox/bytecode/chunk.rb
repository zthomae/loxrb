module Rublox
  module Bytecode
    class Chunk
      def initialize
        @code = []
      end

      def count
        @code.length
      end

      def write(byte)
        @code << byte
      end

      def contents_at(offset)
        @code[offset]
      end
    end
  end
end
