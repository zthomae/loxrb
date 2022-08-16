module Lox
  module TreeWalker
    class Environment
      attr_reader :values, :enclosing

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

        raise LanguageRuntimeError.new(name, "Undefined variable '#{name.lexeme}'.")
      end

      def get_at(distance, name)
        ancestor(distance).values[name]
      end

      def ancestor(distance)
        environment = self
        (0...distance).each do
          environment = environment.enclosing
        end
        environment
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

        raise LanguageRuntimeError.new(name, "Undefined variable '#{name.lexeme}'.")
      end

      def assign_at(distance, name, value)
        ancestor(distance).assign(name, value)
      end
    end
  end
end
