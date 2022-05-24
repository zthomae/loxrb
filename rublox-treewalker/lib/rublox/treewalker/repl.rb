module Rublox
  module TreeWalker
    class Repl
      def initialize(input)
        @input = input
      end

      def run
        loop do
          print "> "
          line = @input.gets&.strip
          break if line.nil?
          puts line
        end
      end
    end
  end
end
