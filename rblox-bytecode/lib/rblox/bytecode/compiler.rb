module Rblox
  module Bytecode
    class Compiler
      Local = Struct.new(:name, :depth)

      def initialize(vm, chunk, error_handler)
        @vm = vm
        @chunk = chunk
        @error_handler = error_handler
        @locals = []
        @scope_depth = 0
      end

      def compile(statements)
        statements.each do |statement|
          add_statement_to_chunk(statement)
        end

        # Since this is synthetic, we make it appear as if it comes from the previous line
        emit_return(statements.last&.bounding_lines&.last || 0)
      end

      def visit_block_stmt(stmt)
        @scope_depth += 1
        stmt.statements.each do |statement|
          statement.accept(self)
        end
        @scope_depth -= 1
        locals_to_remove, locals_to_keep = @locals.partition { |local| local.depth > @scope_depth }
        locals_to_remove.each { |local| emit_byte(:pop, stmt.bounding_lines.last) }
        @locals = locals_to_keep
      end

      def visit_expression_stmt(stmt)
        stmt.expression.accept(self)
        emit_byte(:pop, stmt.bounding_lines.last)
      end

      def visit_print_stmt(stmt)
        stmt.expression.accept(self)
        emit_byte(:print, stmt.bounding_lines.first)
      end

      def visit_var_stmt(stmt)
        if @scope_depth == 0
          # Now that's what I call dynamic typing
          global = emit_string_literal(stmt.name.lexeme, stmt.name.line)

          if stmt.initializer.nil?
            emit_byte(:nil, stmt.bounding_lines.first)
          else
            stmt.initializer.accept(self)
          end

          # Using the last bounding line to match what was just emitted
          emit_bytes(:define_global, global, stmt.bounding_lines.last)
          emit_byte(:pop, stmt.bounding_lines.last)
        else
          if stmt.initializer.nil?
            emit_byte(:nil, stmt.bounding_lines.first)
          else
            stmt.initializer.accept(self)
          end

          if @locals.size > 255
            @error_handler.compile_error(@token, "Too many local variables in function.")
            return
          end

          @locals.reverse.each do |local|
            if local.depth != -1 && local.depth < @scope_depth
              break
            end

            if local.name == stmt.name.lexeme
              @error_handler.compile_error(@token, "Already a variable with this name in scope.")
            end
          end

          @locals << Local.new(stmt.name.lexeme, @scope_depth)
        end
      end

      def visit_assign_expr(expr)
        line = expr.name.bounding_lines.first
        variable_depth = resolve_local(expr.name.lexeme)
        if variable_depth == -1
          arg = emit_string_literal(expr.name.lexeme, line)
          emit_byte(:pop, line)
          expr.value.accept(self)
          emit_bytes(:set_global, arg, line)
        else
          expr.value.accept(self)
          emit_bytes(:set_local, variable_depth, line)
        end
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

      def visit_variable_expr(expr)
        line = expr.name.bounding_lines.first
        variable_depth = resolve_local(expr.name.lexeme)
        if variable_depth == -1
          arg = emit_string_literal(expr.name.lexeme, line)
          emit_byte(:pop, line)
          emit_bytes(:get_global, arg, line)
        else
          emit_bytes(:get_local, variable_depth, line)
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

      def resolve_local(name)
        @locals.reverse.each.with_index do |local, i|
          if name == local.name
            return i
          end
        end

        -1
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
        constant
      end

      def emit_string_literal(value, line)
        obj_string = Rblox::Bytecode.vm_copy_string(@vm, value, value.bytesize)
        emit_constant(:object, obj_string, line)
      end

      def emit_return(line)
        emit_byte(:return, line)
      end
    end
  end
end
