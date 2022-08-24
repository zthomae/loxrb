module Lox
  module TreeWalker
    class UserDefinedClass
      attr_reader :name
      attr_reader :superclass

      def initialize(name, superclass, methods)
        @name = name
        @superclass = superclass
        @methods = methods
      end

      def arity
        initializer = find_method("init")
        return 0 if initializer.nil?

        initializer.arity
      end

      def to_s
        name
      end

      def call(interpreter, arguments)
        instance = UserDefinedClassInstance.new(self)
        initializer = find_method("init")
        initializer&.bind(instance)&.call(interpreter, arguments)

        instance
      end

      def find_method(name)
        if @methods.include?(name)
          return @methods[name]
        end

        return superclass.find_method(name) if !superclass.nil?
      end
    end
  end
end
