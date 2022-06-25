module Rublox
  module TreeWalker
    module Interpreter
      module_function

      def run(source)
        scanner = Scanner.new(source)
        tokens = scanner.scan_tokens

        tokens.each do |token|
          puts token
        end
      end
    end
  end
end
