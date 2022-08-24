module Lox
  module TreeWalker
    class NativeFunction
      attr_reader :arity

      def initialize(arity, &block)
        @arity = arity
        @block = block
      end

      def to_s
        "<native fn>"
      end

      def call(interpreter, arguments)
        @block.call(interpreter, arguments)
      end
    end
  end
end
