module Rblox
  module Bytecode
    class Compiler
      def initialize(vm, chunk, error_handler)
        @vm = vm
        @chunk = chunk
        @error_handler = error_handler
      end

      def compile(statements)
        statements.each do |statement|
          add_statement_to_chunk(statement)
        end

        # Since this is synthetic, we make it appear as if it comes from the previous line
        emit_return(statements.last&.bounding_lines&.last || 0)
      end

      def visit_expression_stmt(stmt)
        stmt.expression.accept(self)
      end

      def visit_binary_expr(expr)
        add_expression_to_chunk(expr.left)
        add_expression_to_chunk(expr.right)

        case expr.operator.type
        when Rblox::Parser::TokenType::BANG_EQUAL
          emit_bytes(:equal, :not, expr.operator.line)
        when Rblox::Parser::TokenType::EQUAL_EQUAL
          emit_byte(:equal, expr.operator.line)
        when Rblox::Parser::TokenType::GREATER
          emit_byte(:greater, expr.operator.line)
        when Rblox::Parser::TokenType::GREATER_EQUAL
          emit_bytes(:less, :not, expr.operator.line)
        when Rblox::Parser::TokenType::LESS
          emit_byte(:less, expr.operator.line)
        when Rblox::Parser::TokenType::LESS_EQUAL
          emit_bytes(:greater, :not, expr.operator.line)
        when Rblox::Parser::TokenType::PLUS
          emit_byte(:add, expr.operator.line)
        when Rblox::Parser::TokenType::MINUS
          emit_byte(:subtract, expr.operator.line)
        when Rblox::Parser::TokenType::STAR
          emit_byte(:multiply, expr.operator.line)
        when Rblox::Parser::TokenType::SLASH
          emit_byte(:divide, expr.operator.line)
        end
      end

      def visit_grouping_expr(expr)
        add_expression_to_chunk(expr.expression)
      end

      def visit_literal_expr(expr)
        case expr.value.literal
        when Float
          emit_constant(:number, expr.value.literal, expr.value.line)
        when String
          emit_string_literal(expr.value.literal, expr.value.line)
        else
          case expr.value.type
          when Rblox::Parser::TokenType::TRUE
            emit_byte(:true, expr.value.line)
          when Rblox::Parser::TokenType::FALSE
            emit_byte(:false, expr.value.line)
          when Rblox::Parser::TokenType::NIL
            emit_byte(:nil, expr.value.line)
          end
        end
      end

      def visit_unary_expr(expr)
        add_expression_to_chunk(expr.right)

        case expr.operator.type
        when Rblox::Parser::TokenType::BANG
          emit_byte(:not, expr.operator.line)
        when Rblox::Parser::TokenType::MINUS
          emit_byte(:negate, expr.operator.line)
        end
      end

      private

      def current_chunk
        @chunk
      end

      def add_statement_to_chunk(stmt)
        stmt.accept(self)
      end

      def add_expression_to_chunk(expr)
        expr.accept(self)
      end

      def emit_byte(byte, line)
        Rblox::Bytecode.chunk_write(current_chunk, byte, line)
      end

      def emit_bytes(byte1, byte2, line)
        emit_byte(byte1, line)
        emit_byte(byte2, line)
      end

      def emit_constant(type, value, line)
        constant = Rblox::Bytecode.public_send("chunk_add_#{type}", current_chunk, value)
        if constant > 255
          @error_handler.compile_error(@token, "Too many constants in one chunk.")
        end
        emit_bytes(:constant, constant, line)
      end

      def emit_string_literal(value, line)
        obj_string = Rblox::Bytecode.vm_copy_string(@vm, value, value.length)
        emit_constant(:object, obj_string, line)
      end

      def emit_return(line)
        emit_byte(:return, line)
      end
    end
  end
end
