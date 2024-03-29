module Lox
  module Bytecode
    class Compiler
      Local = Struct.new(:name, :depth, :is_captured)

      Upvalue = Struct.new(:index, :is_local)

      ClassDeclaration = Struct.new(:enclosing, :has_superclass)

      SyntheticToken = Struct.new(:lexeme, :line)

      module FunctionType
        FUNCTION = :FUNCTION
        INITIALIZER = :INITIALIZER
        METHOD = :METHOD
        SCRIPT = :SCRIPT
      end

      def initialize(vm:, function:, function_type:, error_handler:, enclosing: nil, scope_depth: 0, current_class: nil, disassembler: nil)
        @vm = vm
        @function = function
        @function_type = function_type
        @error_handler = error_handler
        @enclosing = enclosing
        @scope_depth = scope_depth
        @current_class = current_class
        @disassembler = disassembler

        @locals = []
        @locals << if [FunctionType::INITIALIZER, FunctionType::METHOD].include?(function_type)
          Local.new("this", scope_depth, false)
        else
          Local.new("", scope_depth, false)
        end

        @upvalues = []
      end

      def compile(statements)
        statements.each do |statement|
          add_statement_to_chunk(statement)
        end

        # Since this is synthetic, we make it appear as if it comes from the previous line
        emit_return(nil, statements.last&.bounding_lines&.last || 0)

        @disassembler&.disassemble_function(@function)

        @function
      end

      def visit_block_stmt(stmt)
        begin_scope
        stmt.statements.each do |statement|
          statement.accept(self)
        end
        end_scope(stmt.bounding_lines.last)
      end

      def visit_class_stmt(stmt)
        if global_scope?
          global = declare_global(stmt.name)
          emit_bytes(:class, global, stmt.bounding_lines.first)
          define_global(global, stmt.bounding_lines.first)
        else
          declare_local(stmt.name)
          constant = make_identifier_constant(stmt.name, stmt.name.lexeme)
          emit_bytes(:class, constant, stmt.bounding_lines.first)
          mark_new_local_initialized
        end

        original_current_class = @current_class
        @current_class = ClassDeclaration.new(original_current_class, false)

        if !stmt.superclass.nil?
          if stmt.superclass.name.lexeme == stmt.name.lexeme
            @error_handler.compile_error(stmt.superclass.name, "A class can't inherit from itself.")
          end

          get_named_variable(stmt.superclass.name)
          begin_scope
          @locals << Local.new("super", -1, false)
          if global_scope?
            define_global(0, stmt.superclass.name.line)
          else
            mark_new_local_initialized
          end

          get_named_variable(stmt.name)
          emit_byte(:inherit, stmt.superclass.name.line)
          @current_class.has_superclass = true
        end

        # Put the class back on the stack
        get_named_variable(stmt.name)

        stmt.methods.each do |method|
          constant = make_identifier_constant(method.name, method.name.lexeme)
          function_type = method.name.lexeme == "init" ? FunctionType::INITIALIZER : FunctionType::METHOD
          compile_function(method, function_type)
          emit_bytes(:method, constant, method.bounding_lines.first)
        end

        emit_byte(:pop, stmt.bounding_lines.last)

        end_scope(stmt.bounding_lines.last) if @current_class.has_superclass

        @current_class = original_current_class
      end

      def visit_expression_stmt(stmt)
        stmt.expression.accept(self)
        emit_byte(:pop, stmt.bounding_lines.last)
      end

      def visit_function_stmt(stmt)
        if global_scope?
          global = declare_global(stmt.name)
          compile_function(stmt, FunctionType::FUNCTION)
          # Using the last bounding line to match what was just emitted
          define_global(global, stmt.bounding_lines.last)
        else
          declare_local(stmt.name)
          # Mark functions as initialized immediately
          mark_new_local_initialized
          compile_function(stmt, FunctionType::FUNCTION)
        end
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

      def visit_return_stmt(stmt)
        if @function_type == FunctionType::SCRIPT
          @error_handler.compile_error(stmt.keyword, "Can't return from top-level code.")
        elsif @function_type == FunctionType::INITIALIZER && !stmt.value.nil?
          @error_handler.compile_error(stmt.keyword, "Can't return a value from an initializer.")
        end

        emit_return(stmt.value, stmt.keyword.line)
      end

      def visit_var_stmt(stmt)
        if global_scope?
          global = declare_global(stmt.name)
          emit_var_initializer(stmt)
          # Using the last bounding line to match what was just emitted
          define_global(global, stmt.bounding_lines.last)
        else
          declare_local(stmt.name)
          emit_var_initializer(stmt)
          mark_new_local_initialized
        end
      end

      def visit_while_stmt(stmt)
        loop_start = current_chunk[:count]
        stmt.condition.accept(self)
        exit_jump = emit_jump(:jump_if_false, stmt.condition.bounding_lines.last)
        emit_byte(:pop, stmt.condition.bounding_lines.last)
        stmt.body.accept(self)
        emit_loop(loop_start, stmt, exit_jump)
        emit_byte(:pop, stmt.bounding_lines.last)
      end

      def visit_assign_expr(expr)
        expr.value.accept(self)
        line = expr.name.bounding_lines.first
        variable_depth = resolve_local(expr.name, expr.name.lexeme)
        if variable_depth != -1
          emit_bytes(:set_local, variable_depth, line)
        else
          upvalue = resolve_upvalue(expr.name, expr.name.lexeme)
          if upvalue != -1
            emit_bytes(:set_upvalue, upvalue, line)
          else
            constant = make_identifier_constant(expr.name, expr.name.lexeme)
            emit_bytes(:set_global, constant, line)
          end
        end
      end

      def visit_binary_expr(expr)
        add_expression_to_chunk(expr.left)
        add_expression_to_chunk(expr.right)

        case expr.operator.type
        when Lox::Parser::TokenType::BANG_EQUAL
          emit_bytes(:equal, :not, expr.operator.line)
        when Lox::Parser::TokenType::EQUAL_EQUAL
          emit_byte(:equal, expr.operator.line)
        when Lox::Parser::TokenType::GREATER
          emit_byte(:greater, expr.operator.line)
        when Lox::Parser::TokenType::GREATER_EQUAL
          emit_bytes(:less, :not, expr.operator.line)
        when Lox::Parser::TokenType::LESS
          emit_byte(:less, expr.operator.line)
        when Lox::Parser::TokenType::LESS_EQUAL
          emit_bytes(:greater, :not, expr.operator.line)
        when Lox::Parser::TokenType::PLUS
          emit_byte(:add, expr.operator.line)
        when Lox::Parser::TokenType::MINUS
          emit_byte(:subtract, expr.operator.line)
        when Lox::Parser::TokenType::STAR
          emit_byte(:multiply, expr.operator.line)
        when Lox::Parser::TokenType::SLASH
          emit_byte(:divide, expr.operator.line)
        end
      end

      def visit_call_expr(expr)
        if expr.callee.is_a?(Lox::Parser::Expr::Get)
          expr.callee.object.accept(self)
          constant = make_identifier_constant(expr.callee.name, expr.callee.name.lexeme)
          arg_count = argument_list(expr.arguments)
          emit_bytes(:invoke, constant, expr.callee.name.line)
          emit_byte(arg_count, expr.callee.name.line)
        elsif expr.callee.is_a?(Lox::Parser::Expr::Super)
          validate_super_call(expr.callee.keyword)

          get_named_variable(SyntheticToken.new("this", expr.callee.method.line))
          constant = make_identifier_constant(expr.callee.method, expr.callee.method.lexeme)
          arg_count = argument_list(expr.arguments)
          get_named_variable(SyntheticToken.new("super", expr.callee.method.line))
          emit_bytes(:super_invoke, constant, expr.callee.method.line)
          emit_byte(arg_count, expr.callee.method.line)
        else
          expr.callee.accept(self)
          arg_count = argument_list(expr.arguments)
          emit_bytes(:call, arg_count, expr.bounding_lines.first)
        end
      end

      def visit_get_expr(expr)
        expr.object.accept(self)
        constant = make_identifier_constant(expr.name, expr.name.lexeme)
        emit_bytes(:get_property, constant, expr.name.line)
      end

      def visit_grouping_expr(expr)
        add_expression_to_chunk(expr.expression)
      end

      def visit_literal_expr(expr)
        case expr.value.literal
        when Float
          constant = make_constant(:number, expr.value, expr.value.literal)
          emit_bytes(:constant, constant, expr.value.line)
        when String
          constant = make_identifier_constant(expr.value, expr.value.literal)
          emit_bytes(:constant, constant, expr.value.line)
        else
          case expr.value.type
          when Lox::Parser::TokenType::TRUE
            emit_byte(:true, expr.value.line) # standard:disable Lint/BooleanSymbol
          when Lox::Parser::TokenType::FALSE
            emit_byte(:false, expr.value.line) # standard:disable Lint/BooleanSymbol
          when Lox::Parser::TokenType::NIL
            emit_byte(:nil, expr.value.line)
          end
        end
      end

      def visit_logical_expr(expr)
        expr.left.accept(self)
        if expr.operator.type == Lox::Parser::TokenType::AND
          end_jump = emit_jump(:jump_if_false, expr.operator.line)
        else
          else_jump = emit_jump(:jump_if_false, expr.operator.line)
          end_jump = emit_jump(:jump, expr.operator.line)
          patch_jump(else_jump, expr.operator.line)
        end
        emit_byte(:pop, expr.operator.line)
        expr.right.accept(self)
        patch_jump(end_jump, expr.operator.line)
      end

      def visit_set_expr(expr)
        expr.object.accept(self)
        constant = make_identifier_constant(expr.name, expr.name.lexeme)
        expr.value.accept(self)
        emit_bytes(:set_property, constant, expr.name.line)
      end

      def visit_super_expr(expr)
        validate_super_call(expr.keyword)

        constant = make_identifier_constant(expr.method, expr.method.lexeme)

        get_named_variable(SyntheticToken.new("this", expr.method.line))
        get_named_variable(SyntheticToken.new("super", expr.method.line))
        emit_bytes(:get_super, constant, expr.method.line)
      end

      def visit_this_expr(expr)
        if @current_class.nil?
          @error_handler.compile_error(expr.keyword, "Can't use 'this' outside of a class.")
          return
        end
        get_named_variable(expr.keyword)
      end

      def visit_unary_expr(expr)
        add_expression_to_chunk(expr.right)

        case expr.operator.type
        when Lox::Parser::TokenType::BANG
          emit_byte(:not, expr.operator.line)
        when Lox::Parser::TokenType::MINUS
          emit_byte(:negate, expr.operator.line)
        end
      end

      def visit_variable_expr(expr)
        get_named_variable(expr.name)
      end

      def declare_local(name)
        if @locals.size > 255
          @error_handler.compile_error(name, "Too many local variables in function.")
          return
        end

        @locals.reverse_each do |local|
          if local.depth != -1 && local.depth < @scope_depth
            break
          end

          if local.name == name.lexeme
            @error_handler.compile_error(name, "Already a variable with this name in this scope.")
          end
        end

        @locals << Local.new(name.lexeme, -1, false)
      end

      def mark_new_local_initialized
        mark_initialized(@locals[-1])
      end

      def resolve_local(token, name)
        (@locals.length - 1).downto(0).each do |i|
          local = @locals[i]
          if name == local.name
            if local.depth == -1
              @error_handler.compile_error(token, "Can't read local variable in its own initializer.")
            end

            return i
          end
        end

        -1
      end

      def resolve_upvalue(token, name)
        return -1 if @enclosing.nil?

        local = @enclosing.resolve_local(token, name)
        if local != -1
          @enclosing.capture_local(local)
          return add_upvalue(token, local, true)
        end

        upvalue = @enclosing.resolve_upvalue(token, name)
        return add_upvalue(token, upvalue, false) if upvalue != -1

        -1
      end

      def capture_local(index)
        @locals[index].is_captured = true
      end

      def upvalues
        @upvalues.dup
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

      def begin_scope
        @scope_depth += 1
      end

      def end_scope(line)
        @scope_depth -= 1
        locals_to_remove, locals_to_keep = @locals.partition { |local| local.depth > @scope_depth }
        locals_to_remove.reverse_each do |local|
          if local.is_captured
            emit_byte(:close_upvalue, line)
          else
            emit_byte(:pop, line)
          end
        end
        @locals = locals_to_keep
      end

      def global_scope?
        @scope_depth == 0
      end

      def get_named_variable(token)
        line = token.line
        variable_depth = resolve_local(token, token.lexeme)
        if variable_depth != -1
          emit_bytes(:get_local, variable_depth, line)
        else
          upvalue = resolve_upvalue(token, token.lexeme)
          if upvalue != -1
            emit_bytes(:get_upvalue, upvalue, line)
          else
            constant = make_identifier_constant(token, token.lexeme)
            emit_bytes(:get_global, constant, line)
          end
        end
      end

      def declare_global(name)
        make_identifier_constant(name, name.lexeme)
      end

      def define_global(global, line)
        emit_bytes(:define_global, global, line)
      end

      def add_upvalue(token, index, is_local)
        upvalue = @function[:upvalue_count]
        @upvalues.each.with_index do |upvalue, i|
          if upvalue.index == index && upvalue.is_local == is_local
            return i
          end
        end

        if upvalue == 256
          @error_handler.compile_error(token, "Too many closure variables in function.")
          return 0
        end
        @upvalues << Upvalue.new(index, is_local)
        @function[:upvalue_count] += 1
        upvalue
      end

      def emit_var_initializer(stmt)
        if stmt.initializer.nil?
          emit_byte(:nil, stmt.bounding_lines.first)
        else
          stmt.initializer.accept(self)
        end
      end

      def mark_initialized(local)
        if global_scope?
          raise "Programmer error: mark_initialized called in global scope"
        end

        local.depth = @scope_depth
      end

      def argument_list(arguments)
        arg_count = 0
        arguments.each do |argument|
          argument.accept(self)
          if arg_count == 255
            @error_handler.compile_error(argument, "Can't have more than 255 arguments.")
          end
          arg_count += 1
        end
        arg_count
      end

      def compile_function(stmt, function_type)
        function = Lox::Bytecode.vm_new_function(@vm)
        function[:name] = Lox::Bytecode.vm_copy_string(@vm, stmt.name.lexeme, stmt.name.lexeme.bytesize)
        compiler = Compiler.new(
          vm: @vm,
          function: function,
          function_type: function_type,
          error_handler: @error_handler,
          enclosing: self,
          scope_depth: @scope_depth + 1,
          current_class: @current_class,
          disassembler: @disassembler
        )
        stmt.params.each do |param|
          function[:arity] += 1
          if function[:arity] > 255
            @error_handler.compile_error(param, "Can't have more than 255 parameters.")
          end
          compiler.declare_local(param)
          compiler.mark_new_local_initialized
        end
        compiler.compile(stmt.body)
        emit_bytes(:closure, make_constant(:object, stmt.name, function), stmt.name.line)
        (0...function[:upvalue_count]).each do |i|
          emit_byte(compiler.upvalues[i].is_local ? 1 : 0, stmt.name.line)
          emit_byte(compiler.upvalues[i].index, stmt.name.line)
        end
      end

      def validate_super_call(keyword)
        if @current_class.nil?
          @error_handler.compile_error(keyword, "Can't use 'super' outside of a class.")
        elsif !@current_class.has_superclass
          @error_handler.compile_error(keyword, "Can't use 'super' in a class with no superclass.")
        end
      end

      def emit_byte(byte, line)
        Lox::Bytecode.chunk_write(current_chunk, byte, line)
      end

      def emit_bytes(byte1, byte2, line)
        emit_byte(byte1, line)
        emit_byte(byte2, line)
      end

      def make_constant(type, token, value)
        constant = Lox::Bytecode.public_send("chunk_add_#{type}", current_chunk, value)
        if constant > 255
          @error_handler.compile_error(token, "Too many constants in one chunk.")
        end
        constant
      end

      def make_identifier_constant(token, value)
        obj_string = Lox::Bytecode.vm_copy_string(@vm, value, value.bytesize)
        make_constant(:object, token, obj_string)
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

      def emit_loop(loop_start, stmt, exit_jump)
        loop_line = stmt.condition.bounding_lines.first
        emit_byte(:loop, loop_line)

        offset = current_chunk[:count] - loop_start + 2

        if offset > 0xffff
          @error_handler.tokenless_compile_error(stmt.body.bounding_lines.last, "Loop body too large.")
        else
          emit_byte((offset >> 8) & 0xff, loop_line)
          emit_byte(offset & 0xff, loop_line)

          patch_jump(exit_jump, stmt.condition.bounding_lines.last)
        end
      end

      def emit_return(value, line)
        if value.nil?
          if @function_type == FunctionType::INITIALIZER
            emit_bytes(:get_local, 0, line)
          else
            emit_byte(:nil, line)
          end
        else
          value.accept(self)
        end
        emit_byte(:return, line)
      end
    end
  end
end
