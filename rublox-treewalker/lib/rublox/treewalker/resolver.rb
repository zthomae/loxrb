module Rublox
  module TreeWalker
    class Resolver
      def initialize(interpreter, error_handler)
        @interpreter = interpreter
        @error_handler = error_handler
        @scopes = []
        @current_function = FunctionType::NONE
        @current_class = ClassType::NONE
      end

      def visit_block_stmt(stmt)
        begin_scope
        resolve(stmt.statements)
        end_scope
        nil
      end

      def visit_class_stmt(stmt)
        enclosing_class = @current_class
        @current_class = ClassType::CLASS

        declare(stmt.name)
        define(stmt.name)

        if !stmt.superclass.nil? && stmt.name.lexeme == stmt.superclass.name.lexeme
          @error_handler.resolution_error(stmt.superclass.name, "A class can't inherit from itself.")
        end

        if !stmt.superclass.nil?
          @current_class = ClassType::SUBCLASS
          resolve(stmt.superclass)
        end

        if !stmt.superclass.nil?
          begin_scope
          @scopes[-1]["super"] = true
        end

        begin_scope
        @scopes[-1]["this"] = true

        stmt.methods.each do |method|
          declaration = FunctionType::METHOD
          if method.name.lexeme == "init"
            declaration = FunctionType::INITIALIZER
          end
          resolve_function(method, declaration)
        end

        end_scope

        end_scope if !stmt.superclass.nil?

        @current_class = enclosing_class
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

        if !stmt.value.nil?
          if @current_function == FunctionType::INITIALIZER
            @error_handler.resolution_error(stmt.keyword, "Can't return a value from an initializer.")
          end

          resolve(stmt.value)
        end
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

      def visit_get_expr(expr)
        resolve(expr.object)
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

      def visit_set_expr(expr)
        resolve(expr.value)
        resolve(expr.object)
        nil
      end

      def visit_super_expr(expr)
        if @current_class == ClassType::NONE
          @error_handler.resolution_error(expr.keyword, "Can't use 'super' outside of a class.")
        elsif @current_class == ClassType::CLASS
          @error_handler.resolution_error(expr.keyword, "Can't use 'super' in a class with no superclass.")
        end

        resolve_local(expr, expr.keyword)
        nil
      end

      def visit_this_expr(expr)
        if @current_class == ClassType::NONE
          @error_handler.resolution_error(expr.keyword, "Can't use 'this' outside of a class.")
          return
        end

        resolve_local(expr, expr.keyword)
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
        INITIALIZER = "INITIALIZER"
        METHOD = "METHOD"
      end

      module ClassType
        NONE = "NONE"
        CLASS = "CLASS"
        SUBCLASS = "SUBCLASS"
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
