module Rublox
  module Bytecode
    class Chunk
      def initialize
        @code = []
        @constants = []
        @lines = []
      end

      def count
        @code.length
      end

      def write(byte, line)
        @code << byte
        @lines << line
      end

      def add_constant(value)
        @constants << value
        @constants.length - 1
      end

      def contents_at(offset)
        @code[offset]
      end

      def constant_at(offset)
        @constants[offset]
      end

      def line_at(offset)
        @lines[offset]
      end
    end
  end
end
