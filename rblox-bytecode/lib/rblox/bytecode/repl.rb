module Rblox
  module Bytecode
    class Repl
      def initialize(input, interpreter, debug_mode: false)
        @input = input
        @interpreter = interpreter
        @debug_mode = debug_mode
      end

      def run
        loop do
          print "> "
          line = @input.gets&.strip
          break if line.nil?
          @interpreter.run(line, debug_mode: @debug_mode)
          @interpreter.clear_error!
        end
      end
    end
  end
end
