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
          instruction = chunk.contents_at(offset)
          case instruction
          when Opcode::RETURN
            return simple_instruction("OP_RETURN", offset)
          else
            puts "Unknown opcode #{instruction}\n"
            return offset + 1
          end
        end

        private

        def simple_instruction(name, offset)
          puts name
          offset + 1
        end
      end
    end
  end
end
