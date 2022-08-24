module Lox
  module Bytecode
    class Disassembler
      def initialize(io)
        @io = io
      end

      def disassemble_function(function)
        function_name = function[:name][:chars] || "<script>"
        disassemble_chunk(function[:chunk], function_name)
      end

      def disassemble_chunk(chunk, name)
        io.puts "[DEBUG] == #{name} =="

        offset = 0
        count = chunk[:count]
        while offset < count
          offset = disassemble_instruction(chunk, offset)
        end
      end

      def disassemble_instruction(chunk, offset)
        io.print "[DEBUG] %04d " % offset
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
        when Opcode[:true] # standard:disable Lint/BooleanSymbol
          simple_instruction("OP_TRUE", offset)
        when Opcode[:false] # standard:disable Lint/BooleanSymbol
          simple_instruction("OP_FALSE", offset)
        when Opcode[:pop]
          simple_instruction("OP_POP", offset)
        when Opcode[:get_local]
          byte_instruction("OP_GET_LOCAL", chunk, offset)
        when Opcode[:set_local]
          byte_instruction("OP_SET_LOCAL", chunk, offset)
        when Opcode[:get_global]
          constant_instruction("OP_GET_GLOBAL", chunk, offset)
        when Opcode[:define_global]
          constant_instruction("OP_DEFINE_GLOBAL", chunk, offset)
        when Opcode[:set_global]
          constant_instruction("OP_SET_GLOBAL", chunk, offset)
        when Opcode[:get_upvalue]
          byte_instruction("OP_GET_UPVALUE", chunk, offset)
        when Opcode[:set_upvalue]
          byte_instruction("OP_SET_UPVALUE", chunk, offset)
        when Opcode[:get_property]
          constant_instruction("OP_GET_PROPERTY", chunk, offset)
        when Opcode[:set_property]
          constant_instruction("OP_SET_PROPERTY", chunk, offset)
        when Opcode[:get_super]
          constant_instruction("OP_GET_SUPER", chunk, offset)
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
        when Opcode[:jump]
          jump_instruction("OP_JUMP", 1, chunk, offset)
        when Opcode[:jump_if_false]
          jump_instruction("OP_JUMP_IF_FALSE", 1, chunk, offset)
        when Opcode[:loop]
          jump_instruction("OP_LOOP", -1, chunk, offset)
        when Opcode[:call]
          byte_instruction("OP_CALL", chunk, offset)
        when Opcode[:invoke]
          invoke_instruction("OP_INVOKE", chunk, offset)
        when Opcode[:super_invoke]
          invoke_instruction("OP_SUPER_INVOKE", chunk, offset)
        when Opcode[:closure]
          constant_index = chunk.contents_at(offset + 1)
          offset += 2
          constant = chunk.constant_at(constant_index)
          io.puts "%-16s %4d '%s'" % ["OP_CLOSURE", constant_index, constant.to_s]

          function = constant[:as][:obj].as_function
          (0...function[:upvalue_count]).each do
            is_local = chunk.contents_at(offset) == 1
            index = chunk.contents_at(offset + 1)
            io.puts "[DEBUG] %04d      |                     %s %d\n" % [offset, is_local ? "local" : "upvalue", index]
            offset += 2
          end

          offset
        when Opcode[:close_upvalue]
          simple_instruction("OP_CLOSE_UPVALUE", offset)
        when Opcode[:return]
          simple_instruction("OP_RETURN", offset)
        when Opcode[:class]
          constant_instruction("OP_CLASS", chunk, offset)
        when Opcode[:inherit]
          simple_instruction("OP_INHERIT", offset)
        when Opcode[:method]
          constant_instruction("OP_METHOD", chunk, offset)
        else
          io.puts "Unknown opcode #{instruction}\n"
          offset + 1
        end
      ensure
        io.flush
      end

      private

      attr_reader :io

      def constant_instruction(name, chunk, offset)
        constant_index = chunk.contents_at(offset + 1)
        constant = chunk.constant_at(constant_index)
        case constant[:type]
        when :number
          io.puts "%-16s %4d '%g'" % [name, constant_index, constant[:as][:number]]
        when :obj
          io.puts "%-16s %4d '%s'" % [name, constant_index, constant[:as][:obj].to_s.dump]
        end

        offset + 2
      end

      def simple_instruction(name, offset)
        io.puts name
        offset + 1
      end

      def byte_instruction(name, chunk, offset)
        slot = chunk.contents_at(offset + 1)
        io.puts "%-16s %4d\n" % [name, slot]
        offset + 2
      end

      def jump_instruction(name, sign, chunk, offset)
        jump = (chunk.contents_at(offset + 1) << 8) | chunk.contents_at(offset + 2)
        io.puts "%-16s %4d -> %d\n" % [name, offset, offset + 3 + sign * jump]
        offset + 3
      end

      def invoke_instruction(name, chunk, offset)
        constant = chunk.contents_at(offset + 1)
        arg_count = chunk.contents_at(offset + 2)
        value = chunk.constant_at(constant)
        io.puts "%-16s (%d args) %4d '%s'" % [name, arg_count, constant, value.to_s]
        offset + 3
      end
    end
  end
end
