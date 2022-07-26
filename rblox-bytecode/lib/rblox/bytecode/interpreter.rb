module Rblox
  module Bytecode
    class Interpreter
      def initialize(vm, disassembler: nil)
        @vm = vm
        @disassembler = disassembler
      end

      def interpret(function)
        interpret_result = nil

        if debug_mode?
          Rblox::Bytecode.vm_init_function(@vm, function)
          loop do
            current_function = @vm.current_frame[:function]
            @disassembler.disassemble_instruction(current_function[:chunk], @vm.current_offset)
            interpret_result = Rblox::Bytecode.vm_interpret_next_instruction(@vm)
            pp @vm.stack_contents
            break if interpret_result != :incomplete
          end
        else
          interpret_result = Rblox::Bytecode.vm_interpret(@vm, function)
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
