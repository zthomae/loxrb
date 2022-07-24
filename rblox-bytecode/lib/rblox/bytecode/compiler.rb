module Rblox
  module Bytecode
    class Compiler
      Local = Struct.new(:name, :depth)

      module FunctionType
        FUNCTION = :FUNCTION
        SCRIPT = :SCRIPT
      end

      def initialize(vm, function, function_type, error_handler)
        @vm = vm
        @function = function
        @function_type = function_type
        @error_handler = error_handler
        @locals = [Local.new("", 0)]
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

      def visit_if_stmt(stmt)
        approximate_first_then_line = stmt.then_branch.bounding_lines.first || stmt.condition.bounding_lines.last
        approximate_last_then_line = stmt.then_branch.bounding_lines.last || stmt.else_branch&.bounding_lines&.first || stmt.bounding_lines.last
        stmt.condition.accept(self)
        then_jump = emit_jump(:jump_if_false, approximate_first_then_line)
        emit_byte(:pop, approximate_last_then_line)
        stmt.then_branch.accept(self)
        else_jump = emit_jump(:jump, approximate_last_then_line)
        patch_jump(then_jump, approximate_first_then_line)
        emit_byte(:pop, approximate_last_then_line)
        stmt.else_branch&.accept(self)
        patch_jump(else_jump, approximate_last_then_line)
      end

      def visit_print_stmt(stmt)
        stmt.expression.accept(self)
        emit_byte(:print, stmt.bounding_lines.first)
      end

      def visit_var_stmt(stmt)
        if @scope_depth == 0
          # Now that's what I call dynamic typing
          global = emit_string_literal(stmt.name, stmt.name.lexeme, stmt.name.line)

          if stmt.initializer.nil?
            emit_byte(:nil, stmt.bounding_lines.first)
          else
            stmt.initializer.accept(self)
          end

          # Using the last bounding line to match what was just emitted
          emit_bytes(:define_global, global, stmt.bounding_lines.last)
          emit_byte(:pop, stmt.bounding_lines.last)
        else
          if @locals.size > 255
            @error_handler.compile_error(stmt.name, "Too many local variables in function.")
            return
          end

          @locals.reverse.each do |local|
            if local.depth != -1 && local.depth < @scope_depth
              break
            end

            if local.name == stmt.name.lexeme
              @error_handler.compile_error(stmt.name, "Already a variable with this name in this scope.")
            end
          end

          @locals << Local.new(stmt.name.lexeme, -1)

          if stmt.initializer.nil?
            emit_byte(:nil, stmt.bounding_lines.first)
          else
            stmt.initializer.accept(self)
          end

          @locals[-1].depth = @scope_depth
        end
      end

      def visit_while_stmt(stmt)
        loop_start = current_chunk[:count]
        stmt.condition.accept(self)
        exit_jump = emit_jump(:jump_if_false, stmt.condition.bounding_lines.last)
        emit_byte(:pop, stmt.condition.bounding_lines.last)
        stmt.body.accept(self)
        emit_loop(loop_start, stmt.condition.bounding_lines.first)
        patch_jump(exit_jump, stmt.condition.bounding_lines.last)
        emit_byte(:pop, stmt.bounding_lines.last)
      end

      def visit_assign_expr(expr)
        line = expr.name.bounding_lines.first
        variable_depth = resolve_local(expr.name, expr.name.lexeme)
        if variable_depth == -1
          arg = emit_string_literal(expr.name, expr.name.lexeme, line)
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
          emit_constant(:number, expr.value, expr.value.literal, expr.value.line)
        when String
          emit_string_literal(expr.value, expr.value.literal, expr.value.line)
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

      def visit_logical_expr(expr)
        expr.left.accept(self)
        if expr.operator.type == Rblox::Parser::TokenType::AND
          end_jump = emit_jump(:jump_if_false, expr.operator.line)
          emit_byte(:pop, expr.operator.line)
          expr.right.accept(self)
          patch_jump(end_jump, expr.operator.line)
        else
          else_jump = emit_jump(:jump_if_false, expr.operator.line)
          end_jump = emit_jump(:jump, expr.operator.line)
          patch_jump(else_jump, expr.operator.line)
          emit_byte(:pop, expr.operator.line)
          expr.right.accept(self)
          patch_jump(end_jump, expr.operator.line)
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
        variable_depth = resolve_local(expr.name, expr.name.lexeme)
        if variable_depth == -1
          arg = emit_string_literal(expr.name, expr.name.lexeme, line)
          emit_byte(:pop, line)
          emit_bytes(:get_global, arg, line)
        else
          emit_bytes(:get_local, variable_depth, line)
        end
      end

      private

      def current_chunk
        @function[:chunk]
      end

      def add_statement_to_chunk(stmt)
        stmt.accept(self)
      end

      def add_expression_to_chunk(expr)
        expr.accept(self)
      end

      def resolve_local(token, name)
        (@locals.length - 1).downto(0).each do |i|
          local = @locals[i]
          if name == local.name
            if local.depth == -1
              @error_handler.compile_error(token, "Can't read local variable in its own initializer.")
            end

            return i - 1
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

      def emit_constant(type, token, value, line)
        constant = Rblox::Bytecode.public_send("chunk_add_#{type}", current_chunk, value)
        if constant > 255
          @error_handler.compile_error(token, "Too many constants in one chunk.")
        end
        emit_bytes(:constant, constant, line)
        constant
      end

      def emit_string_literal(token, value, line)
        obj_string = Rblox::Bytecode.vm_copy_string(@vm, value, value.bytesize)
        emit_constant(:object, token, obj_string, line)
      end

      def emit_jump(instruction, line)
        emit_byte(instruction, line)
        emit_byte(0xff, line)
        emit_byte(0xff, line)
        current_chunk[:count] - 2
      end

      def patch_jump(offset, line)
        # -2 to adjust for the bytecode for the jump offset itself.
        jump = current_chunk[:count] - offset - 2

        if jump > 0xffff
          @error_handler.tokenless_compile_error(line, "Too much code to jump over.")
        end

        current_chunk.patch_contents_at(offset, (jump >> 8) & 0xff)
        current_chunk.patch_contents_at(offset + 1, jump & 0xff)
      end

      def emit_loop(loop_start, line)
        emit_byte(:loop, line)

        offset = current_chunk[:count] - loop_start + 2

        if offset > 0xffff
          @error_handler.tokenless_compile_error(line, "Loop body too large.")
        end

        emit_byte((offset >> 8) & 0xff, line)
        emit_byte(offset & 0xff, line)
      end

      def emit_return(line)
        emit_byte(:return, line)
      end
    end
  end
end
