module Rublox
  module Bytecode
    module Disassembler
      class << self
        def disassemble_chunk(chunk, name)
          puts "== #{name} =="

          offset = 0
          count = chunk.count
          while offset < count
            offset = disassemble_instruction(chunk, offset)
          end
        end

        def disassemble_instruction(chunk, offset)
          print "%04d " % offset
          current_line = chunk.line_at(offset)
          if offset > 0 && current_line == chunk.line_at(offset - 1)
            print "   | "
          else
            print "%4d " % current_line
          end

          instruction = chunk.contents_at(offset)
          case instruction
          when Opcode::CONSTANT
            constant_instruction("OP_CONSTANT", chunk, offset)
          when Opcode::RETURN
            simple_instruction("OP_RETURN", offset)
          else
            puts "Unknown opcode #{instruction}\n"
            offset + 1
          end
        end

        private

        def constant_instruction(name, chunk, offset)
          constant = chunk.contents_at(offset + 1)
          puts "%-16s %4d '%g'" % [name, constant, chunk.constant_at(constant)]
          offset + 2
        end

        def simple_instruction(name, offset)
          puts name
          offset + 1
        end
      end
    end
  end
end
