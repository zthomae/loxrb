module Rblox
  module Bytecode
    class Interpreter
      def initialize(vm, disassembler: nil)
        @vm = vm
        @disassembler = disassembler
      end

      def interpret(chunk)
        interpret_result = nil

        if debug_mode?
          Rblox::Bytecode.vm_init_chunk(@vm, chunk)
          loop do
            @disassembler.disassemble_instruction(chunk, @vm.current_offset)
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
        !!@disassembler
      end

      def execute(statement)

      end
    end
  end
end
