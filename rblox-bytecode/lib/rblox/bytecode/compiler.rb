module Rblox
  module Bytecode
    class Compiler
      def initialize(chunk, error_handler)
        @chunk = chunk
        @error_handler = error_handler
        @token = nil
        @line = 0
      end

      def compile(statements)
        statements.each do |statement|
          add_statement_to_chunk(statement)
        end

        emit_return
      end

      def visit_expression_stmt(stmt)
        stmt.expression.accept(self)
      end

      def visit_binary_expr(expr)
        update_token(expr.operator)

        add_expression_to_chunk(expr.left)
        add_expression_to_chunk(expr.right)

        case expr.operator.type
        when Rblox::Parser::TokenType::BANG_EQUAL
          emit_bytes(:equal, :not)
        when Rblox::Parser::TokenType::EQUAL_EQUAL
          emit_byte(:equal)
        when Rblox::Parser::TokenType::GREATER
          emit_byte(:greater)
        when Rblox::Parser::TokenType::GREATER_EQUAL
          emit_bytes(:less, :not)
        when Rblox::Parser::TokenType::LESS
          emit_byte(:less)
        when Rblox::Parser::TokenType::LESS_EQUAL
          emit_bytes(:greater, :not)
        when Rblox::Parser::TokenType::PLUS
          emit_byte(:add)
        when Rblox::Parser::TokenType::MINUS
          emit_byte(:subtract)
        when Rblox::Parser::TokenType::STAR
          emit_byte(:multiply)
        when Rblox::Parser::TokenType::SLASH
          emit_byte(:divide)
        end
      end

      def visit_grouping_expr(expr)
        add_expression_to_chunk(expr.expression)
      end

      def visit_literal_expr(expr)
        case expr.value
        when NilClass
          emit_byte(:nil)
        when TrueClass
          emit_byte(:true)
        when FalseClass
          emit_byte(:false)
        when Float
          emit_constant(expr.value)
        end
      end

      def visit_unary_expr(expr)
        add_expression_to_chunk(expr.right)

        case expr.operator.type
        when Rblox::Parser::TokenType::BANG
          emit_byte(:not)
        when Rblox::Parser::TokenType::MINUS
          emit_byte(:negate)
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

      def emit_byte(byte)
        Rblox::Bytecode.chunk_write(current_chunk, byte, @line)
      end

      def emit_bytes(byte1, byte2)
        emit_byte(byte1)
        emit_byte(byte2)
      end

      def emit_constant(value)
        constant = Rblox::Bytecode.chunk_add_number(current_chunk, value)
        if constant > 255
          @error_handler.compile_error(@token, "Too many constants in one chunk.")
        end
        emit_bytes(:constant, constant)
      end

      def emit_return
        emit_byte(:return)
      end

      def update_token(token)
        @token = token
        @line = token.line
      end
    end
  end
end
