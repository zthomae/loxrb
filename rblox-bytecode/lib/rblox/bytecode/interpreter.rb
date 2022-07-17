module Rblox
  module Bytecode
    class Interpreter
      def initialize(vm, debug_mode: false)
        @vm = vm
        @debug_mode = debug_mode
      end

      def interpret(chunk)
        interpret_result = nil

        if debug_mode?
          disassembler = Rblox::Bytecode::Disassembler.new($stdout)
          Rblox::Bytecode.vm_init_chunk(@vm, chunk)
          loop do
            disassembler.disassemble_instruction(chunk, @vm.current_offset)
            interpret_result = Rblox::Bytecode.vm_interpret_next_instruction(@vm)
            pp @vm.stack_contents
            break if interpret_result != :incomplete
          end
        else
          interpret_result = Rblox::Bytecode.vm_interpret(@vm, chunk)
        end

        interpret_result
      end

      private

      def debug_mode?
        !!@debug_mode
      end

      def execute(statement)

      end
    end
  end
end
