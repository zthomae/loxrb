module Lox
  module TreeWalker
    class Repl
      def initialize(input, interpreter)
        @input = input
        @interpreter = interpreter
      end

      def run
        loop do
          print "> "
          line = @input.gets&.strip
          break if line.nil?
          @interpreter.run(line)
          @interpreter.clear_error!
        end
      end
    end
  end
end
