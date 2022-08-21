require "lox/parser"

module Lox
  module Bytecode
    class Main
      VmOptions = Struct.new(:log_disassembly, :log_gc, :stress_gc, keyword_init: true) do
        def self.default
          new(log_disassembly: false, log_gc: false, stress_gc: false)
        end
      end

      def initialize(vm_options = nil)
        @vm_options = vm_options || VmOptions.default
        @vm = Lox::Bytecode::VM.new(FFI::MemoryPointer.new(Lox::Bytecode::VM, 1)[0])
        Lox::Bytecode.vm_init(@vm)
        @vm[:memory_allocator][:log_gc] = @vm_options.log_gc
        @vm[:memory_allocator][:stress_gc] = @vm_options.stress_gc
        if @vm_options.log_disassembly
          @disassembler = Lox::Bytecode::Disassembler.new($stdout)
        end
      end

      def run(source)
        @vm[:memory_allocator][:gc_enabled] = false
        scanner = Lox::Parser::Scanner.new(source, self)
        tokens = scanner.scan_tokens

        parser = Lox::Parser::RecursiveDescentParser.new(tokens, self)
        statements = parser.parse!

        return if had_error?

        function = Lox::Bytecode.vm_new_function(@vm)
        compiler = Compiler.new(@vm, function, Compiler::FunctionType::SCRIPT, self)
        compiler.compile(statements)

        return if had_error?

        if log_disassembly?
          @disassembler.disassemble_function(function)
          puts "[DEBUG] "
        end

        @vm[:memory_allocator][:gc_enabled] = true
        interpreter = Interpreter.new(@vm, disassembler: @disassembler)
        interpret_result = interpreter.interpret(function)
        if interpret_result != :ok
          @had_runtime_error = true
        end
      end

      def scan_error(line, message)
        report(line, "", message)
        @had_error = true
      end

      def parse_error(token, message)
        if token.type == Lox::Parser::TokenType::EOF
          report(token.line, " at end", message)
        else
          report(token.line, " at '#{token.lexeme}'", message)
        end
        @had_error = true
      end

      def compile_error(token, message)
        if token.type == Lox::Parser::TokenType::EOF
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

      def log_disassembly?
        @vm_options.log_disassembly
      end

      private

      def report(line, where, message)
        warn("[line #{line}] Error#{where}: #{message}")
      end
    end
  end
end
