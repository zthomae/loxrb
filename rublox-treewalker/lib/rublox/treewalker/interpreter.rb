require "rublox/parser"

module Rublox
  module TreeWalker
    class Interpreter
      class << self
        def run(source)
          scanner = Rublox::Parser::Scanner.new(source)
          tokens = scanner.scan_tokens

          tokens.each do |token|
            puts token
          end
        end

        def error(line, message)
          report(line, "", message)
          @had_error = true
        end

        def had_error?
          !!@had_error
        end

        def clear_error!
          @had_error = false
        end

        private

        def report(line, where, message)
          warn("[line #{line}] Error#{where}: #{message}")
        end
      end
    end
  end
end
