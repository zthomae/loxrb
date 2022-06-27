module Rublox
  module TreeWalker
    class Environment
      def initialize(enclosing = nil)
        @values = {}
        @enclosing = enclosing
      end

      def define(name, value)
        @values[name] = value
      end

      def get(name)
        return @values[name.lexeme] if @values.include?(name.lexeme)
        return @enclosing.get(name) if !@enclosing.nil?

        raise LoxRuntimeError.new(name, "Undefined variable '#{name.lexeme}'.")
      end

      def assign(name, value)
        if @values.include?(name.lexeme)
          @values[name.lexeme] = value
          return
        end

        if !@enclosing.nil?
          @enclosing.assign(name, value)
          return
        end

        raise LoxRuntimeError.new(name, "Undefined variable '#{name.lexeme}'.")
      end
    end
  end
end
