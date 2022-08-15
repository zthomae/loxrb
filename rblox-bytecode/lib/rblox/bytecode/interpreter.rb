module Rblox
  module Bytecode
    class Interpreter
      def initialize(vm, disassembler: nil)
        @vm = vm
        @disassembler = disassembler
      end

      def interpret(function)
        interpret_result = nil

        if log_disassembly?
          Rblox::Bytecode.vm_init_function(@vm, function)
          loop do
            @disassembler.disassemble_instruction(@vm.current_function[:chunk], @vm.current_offset)
            interpret_result = Rblox::Bytecode.vm_interpret_next_instruction(@vm)
            puts "[DEBUG] Stack contents: #{@vm.stack_contents}"
            break if interpret_result != :incomplete
          end
        else
          interpret_result = Rblox::Bytecode.vm_interpret(@vm, function)
        end

        interpret_result
      end

      private

      def log_disassembly?
        !!@disassembler
      end
    end
  end
end
