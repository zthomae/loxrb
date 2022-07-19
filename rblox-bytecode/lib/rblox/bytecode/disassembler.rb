module Rblox
  module Bytecode
    class Disassembler
      def initialize(io)
        @io = io
      end

      def disassemble_chunk(chunk, name)
        io.puts "== #{name} =="

        offset = 0
        count = chunk[:count]
        while offset < count
          offset = disassemble_instruction(chunk, offset)
        end
      end

      def disassemble_instruction(chunk, offset)
        io.print "%04d " % offset
        current_line = chunk.line_at(offset)
        if offset > 0 && current_line == chunk.line_at(offset - 1)
          io.print "   | "
        else
          io.print "%4d " % current_line
        end

        instruction = chunk.contents_at(offset)
        case instruction
        when Opcode[:constant]
          constant_instruction("OP_CONSTANT", chunk, offset)
        when Opcode[:nil]
          simple_instruction("OP_NIL", offset)
        when Opcode[:true]
          simple_instruction("OP_TRUE", offset)
        when Opcode[:false]
          simple_instruction("OP_FALSE", offset)
        when Opcode[:pop]
          simple_instruction("OP_POP", offset)
        when Opcode[:get_global]
          constant_instruction("OP_GET_GLOBAL", chunk, offset)
        when Opcode[:define_global]
          constant_instruction("OP_DEFINE_GLOBAL", chunk, offset)
        when Opcode[:set_global]
          constant_instruction("OP_SET_GLOBAL", chunk, offset)
        when Opcode[:equal]
          simple_instruction("OP_EQUAL", offset)
        when Opcode[:greater]
          simple_instruction("OP_GREATER", offset)
        when Opcode[:less]
          simple_instruction("OP_LESS", offset)
        when Opcode[:add]
          simple_instruction("OP_ADD", offset)
        when Opcode[:subtract]
          simple_instruction("OP_SUBTRACT", offset)
        when Opcode[:multiply]
          simple_instruction("OP_MULTIPLY", offset)
        when Opcode[:divide]
          simple_instruction("OP_DIVIDE", offset)
        when Opcode[:not]
          simple_instruction("OP_NOT", offset)
        when Opcode[:negate]
          simple_instruction("OP_NEGATE", offset)
        when Opcode[:print]
          simple_instruction("OP_PRINT", offset)
        when Opcode[:return]
          simple_instruction("OP_RETURN", offset)
        else
          io.puts "Unknown opcode #{instruction}\n"
          offset + 1
        end
      end

      private

      attr_reader :io

      def constant_instruction(name, chunk, offset)
        constant_index = chunk.contents_at(offset + 1)
        constant = chunk.constant_at(constant_index)
        case constant
        when Float
          io.puts "%-16s %4d '%g'" % [name, constant_index, constant]
        when Rblox::Bytecode::Obj
          case constant[:type]
          when :string
            io.puts "%-16s %4d '%s'" % [name, constant_index, constant.as_string[:chars]]
          else
            io.puts "%-16s %4d '%s'" % [name, constant_index, "Unsupported type: #{constant[:type]}"]
          end
        end

        offset + 2
      end

      def simple_instruction(name, offset)
        io.puts name
        offset + 1
      end
    end
  end
end
