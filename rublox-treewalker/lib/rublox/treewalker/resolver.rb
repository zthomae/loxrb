module Rublox
  module TreeWalker
    class Resolver
      def initialize(interpreter, error_handler)
        @interpreter = interpreter
        @error_handler = error_handler
        @scopes = []
        @current_function = FunctionType::NONE
      end

      def visit_block_stmt(stmt)
        begin_scope
        resolve(stmt.statements)
        end_scope
        nil
      end

      def visit_expression_stmt(stmt)
        resolve(stmt.expression)
        nil
      end

      def visit_function_stmt(stmt)
        declare(stmt.name)
        define(stmt.name)

        resolve_function(stmt, FunctionType::FUNCTION)
        nil
      end

      def visit_if_stmt(stmt)
        resolve(stmt.condition)
        resolve(stmt.then_branch)
        resolve(stmt.else_branch) if !stmt.else_branch.nil?
        nil
      end

      def visit_print_stmt(stmt)
        resolve(stmt.expression)
        nil
      end

      def visit_return_stmt(stmt)
        if @current_function == FunctionType::NONE
          @error_handler.resolution_error(stmt.keyword, "Can't return from top-level code.")
        end

        resolve(stmt.value) if !stmt.value.nil?
        nil
      end

      def visit_var_stmt(stmt)
        declare(stmt.name)
        if !stmt.initializer.nil?
          resolve(stmt.initializer)
        end
        define(stmt.name)
        nil
      end

      def visit_while_stmt(stmt)
        resolve(stmt.condition)
        resolve(stmt.body)
        nil
      end

      def visit_assign_expr(expr)
        resolve(expr.value)
        resolve_local(expr, expr.name)
        nil
      end

      def visit_binary_expr(expr)
        resolve(expr.left)
        resolve(expr.right)
        nil
      end

      def visit_call_expr(expr)
        resolve(expr.callee)
        expr.arguments.each(&method(:resolve))
        nil
      end

      def visit_grouping_expr(expr)
        resolve(expr.expression)
        nil
      end

      def visit_literal_expr(expr)
        nil
      end

      def visit_logical_expr(expr)
        resolve(expr.left)
        resolve(expr.right)
        nil
      end

      def visit_unary_expr(expr)
        resolve(expr.right)
        nil
      end

      def visit_variable_expr(expr)
        if !@scopes.empty? && @scopes[-1][expr.name.lexeme] == false
          @error_handler.resolution_error(expr.name, "Can't read local variable in its own initializer.")
        end

        resolve_local(expr, expr.name)
        nil
      end

      def resolve(entity)
        if entity.is_a?(Array)
          entity.each(&method(:resolve))
        else
          entity.accept(self)
        end
      end

      private

      module FunctionType
        NONE = "NONE"
        FUNCTION = "FUNCTION"
      end

      def begin_scope
        @scopes.push({})
      end

      def end_scope
        @scopes.pop
      end

      def declare(name)
        return if @scopes.empty?

        scope = @scopes[-1]
        if scope.include?(name.lexeme)
          @error_handler.resolution_error(name, "Already a variable with this name in this scope.")
        end
        scope[name.lexeme] = false
      end

      def define(name)
        return if @scopes.empty?

        @scopes[-1][name.lexeme] = true
      end

      def resolve_local(expr, name)
        @scopes.reverse.each.with_index do |scope, i|
          if scope.include?(name.lexeme)
            @interpreter.resolve(expr, i)
            return
          end
        end
      end

      def resolve_function(function, type)
        enclosing_function = @current_function
        @current_function = type

        begin_scope
        function.params.each do |param|
          declare(param)
          define(param)
        end
        resolve(function.body)
        end_scope

        @current_function = enclosing_function
      end
    end
  end
end
