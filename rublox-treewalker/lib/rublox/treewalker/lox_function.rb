module Rublox
  module TreeWalker
    class LoxFunction
      def initialize(declaration, closure)
        @declaration = declaration
        @closure = closure
      end

      def arity
        @declaration.params.size
      end

      def to_s
        "<fn #{@declaration.name.lexeme}>"
      end

      def call(interpreter, arguments)
        environment = Environment.new(@closure)
        @declaration.params.zip(arguments).each do |param, argument|
          environment.define(param.lexeme, argument)
        end

        begin
          interpreter.execute_block(@declaration.body, environment)
        rescue RuntimeReturn => e
          return e.value
        end
      end
    end
  end
end
