module Rblox
  module TreeWalker
    class UserDefinedClassInstance
      def initialize(klass)
        @klass = klass
        @fields = {}
      end

      def to_s
        "#{@klass.name} instance"
      end

      def get(name)
        if @fields.include?(name.lexeme)
          return @fields[name.lexeme]
        end

        method = @klass.find_method(name.lexeme)
        return method.bind(self) if !method.nil?

        raise LanguageRuntimeError.new(name, "Undefined property '#{name.lexeme}'.")
      end

      def set(name, value)
        @fields[name.lexeme] = value
      end
    end
  end
end
