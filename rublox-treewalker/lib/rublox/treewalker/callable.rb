module Rublox
  module TreeWalker
    # In my experience, Ruby doesn't do interfaces very well. The "normal" thing to do here is
    # duck typing. This is an experiment with something different: Unifying behind a single
    # class that's instantiated with a block mimicking how the behavior would be overridden.
    class Callable
      attr_reader :arity

      def initialize(arity, repr, &block)
        @arity = arity
        @repr = repr
        @block = block
      end

      def to_s
        @repr
      end

      def call(interpreter, arguments)
        @block.call(interpreter, arguments)
      end

      def self.create_native(arity, &block)
        new(arity, "<native fn>") do |interpreter, arguments|
          block.call(interpreter, arguments)
        end
      end

      def self.create_function(declaration, closure)
        new(declaration.params.size, "<fn #{declaration.name.lexeme}>") do |interpreter, arguments|
          environment = Environment.new(closure)
          declaration.params.zip(arguments).each do |declaration, argument|
            environment.define(declaration.lexeme, argument)
          end

          begin
            interpreter.execute_block(declaration.body, environment)
          rescue RuntimeReturn => e
            next e.value
          end
        end
      end
    end
  end
end
