module Rublox
  module TreeWalker
    class Environment
      def initialize
        @values = {}
      end

      def define(name, value)
        @values[name] = value
      end

      def get(name)
        return @values[name.lexeme] if @values.include?(name.lexeme)

        raise LoxRuntimeError.new(name, "Undefined variable '#{name.lexeme}'.")
      end
    end
  end
end
