require "rblox/parser"

module Rblox
  module TreeWalker
    class Main
      class << self
        def run(source)
          scanner = Rblox::Parser::Scanner.new(source, self)
          tokens = scanner.scan_tokens

          parser = Rblox::Parser::RecursiveDescentParser.new(tokens, self)
          statements = parser.parse!

          return if had_error?

          resolver = Resolver.new(interpreter, self)
          resolver.resolve(statements)

          return if had_error?

          interpreter.interpret(statements)
        end

        def scan_error(line, message)
          report(line, "", message)
          @had_error = true
        end

        def parse_error(token, message)
          if token.type == Rblox::Parser::TokenType::EOF
            report(token.line, " at end", message)
          else
            report(token.line, " at '#{token.lexeme}'", message)
          end
          @had_error = true
        end

        def resolution_error(name, message)
          report(name.line, " at '#{name.lexeme}'", message)
          @had_error = true
        end

        def runtime_error(error)
          warn "#{error.message}\n[line #{error.token.line}]"
          @had_runtime_error = true
        end

        def had_error?
          !!@had_error
        end

        def had_runtime_error?
          !!@had_runtime_error
        end

        def clear_error!
          @had_error = false
        end

        private

        def interpreter
          @interpreter ||= Interpreter.new(self)
        end

        def report(line, where, message)
          warn("[line #{line}] Error#{where}: #{message}")
        end
      end
    end
  end
end
