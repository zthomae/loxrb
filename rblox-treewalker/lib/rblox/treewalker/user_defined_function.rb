module Rblox
  module TreeWalker
    class UserDefinedFunction
      def initialize(declaration, closure, is_initializer:)
        @declaration = declaration
        @closure = closure
        @is_initializer = is_initializer
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
          return @closure.get_at(0, "this") if is_initializer?
          return e.value
        end

        if is_initializer?
          @closure.get_at(0, "this")
        end
      end

      def bind(instance)
        environment = Environment.new(@closure)
        environment.define("this", instance)
        UserDefinedFunction.new(@declaration, environment, is_initializer: is_initializer?)
      end

      private

      def is_initializer?
        !!@is_initializer
      end
    end
  end
end
