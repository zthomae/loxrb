require "rblox/parser"

module Rblox
  module Bytecode
    class Main
      def initialize(debug_mode: false, stress_gc: false)
        @vm = Rblox::Bytecode::VM.new(FFI::MemoryPointer.new(Rblox::Bytecode::VM, 1)[0])
        Rblox::Bytecode.vm_init(@vm)
        @debug_mode = debug_mode
        @vm[:stress_gc] = stress_gc
      end

      def run(source)
        scanner = Rblox::Parser::Scanner.new(source, self)
        tokens = scanner.scan_tokens

        parser = Rblox::Parser::RecursiveDescentParser.new(tokens, self)
        statements = parser.parse!

        return if had_error?

        if debug_mode
          disassembler = Rblox::Bytecode::Disassembler.new($stdout)
        end

        @vm.with_new_function do |function|
          compiler = Compiler.new(@vm, function, Compiler::FunctionType::SCRIPT, self)
          compiler.compile(statements)

          return if had_error?

          if debug_mode
            disassembler.disassemble_function(function)
            puts "[DEBUG] "
          end

          interpreter = Interpreter.new(@vm, disassembler: disassembler)
          interpret_result = interpreter.interpret(function)
          if interpret_result != :ok
            @had_runtime_error = true
          end
        end
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

      def compile_error(token, message)
        if token.type == Rblox::Parser::TokenType::EOF
          report(token.line, " at end", message)
        else
          report(token.line, " at '#{token.lexeme}'", message)
        end
        @had_error = true
      end

      def tokenless_compile_error(line, message)
        warn("[line #{line}] Error: #{message}")
        @had_error = true
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

      def debug_mode
        !!@debug_mode
      end

      def report(line, where, message)
        warn("[line #{line}] Error#{where}: #{message}")
      end
    end
  end
end
