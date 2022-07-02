module Rublox
  module TreeWalker
    class Interpreter
      attr_reader :globals

      def initialize(error_handler)
        @error_handler = error_handler
        @globals = Environment.new
        @globals.define(
          "clock",
          NativeFunction.new(0) do |interpreter, arguments|
            Time.now.strftime("%s%L").to_f / 1000.0
          end
        )
        @environment = @globals
        @locals = {}
      end

      def interpret(statements)
        statements.each do |statement|
          execute(statement)
        end
      rescue LoxRuntimeError => e
        @error_handler.runtime_error(e)
      end

      def visit_block_stmt(stmt)
        execute_block(stmt.statements, Environment.new(@environment))
      end

      def visit_class_stmt(stmt)
        @environment.define(stmt.name.lexeme, nil)

        methods = {}
        stmt.methods.each do |method|
          function = LoxFunction.new(method, @environment, method.name.lexeme == "init")
          methods[method.name.lexeme] = function
        end

        klass = LoxClass.new(stmt.name.lexeme, methods)
        @environment.assign(stmt.name, klass)
        nil
      end

      def visit_expression_stmt(stmt)
        evaluate(stmt.expression)
        nil
      end

      def visit_function_stmt(stmt)
        function = LoxFunction.new(stmt, @environment, false)
        @environment.define(stmt.name.lexeme, function)
        nil
      end

      def visit_if_stmt(stmt)
        if is_truthy?(evaluate(stmt.condition))
          execute(stmt.then_branch)
        elsif !stmt.else_branch.nil?
          execute(stmt.else_branch)
        end
        nil
      end

      def visit_print_stmt(stmt)
        value = evaluate(stmt.expression)
        puts stringify(value)
        nil
      end

      def visit_return_stmt(stmt)
        if !stmt.value.nil?
          value = evaluate(stmt.value)
        end

        raise RuntimeReturn.new(value)
      end

      def visit_var_stmt(stmt)
        value = nil
        if !stmt.initializer.nil?
          value = evaluate(stmt.initializer)
        end

        @environment.define(stmt.name.lexeme, value)
        nil
      end

      def visit_while_stmt(stmt)
        while is_truthy?(evaluate(stmt.condition))
          execute(stmt.body)
        end
        nil
      end

      def visit_literal_expr(expr)
        return expr.value
      end

      def visit_logical_expr(expr)
        left = evaluate(expr.left)

        if expr.operator.type == Rublox::Parser::TokenType::OR
          return left if is_truthy?(left)
        else
          return left if !is_truthy?(left)
        end

        evaluate(expr.right)
      end

      def visit_grouping_expr(expr)
        evaluate(expr.expression)
      end

      def visit_unary_expr(expr)
        right = evaluate(expr.right)

        case expr.operator.type
        when Rublox::Parser::TokenType::BANG
          !is_truthy?(right)
        when Rublox::Parser::TokenType::MINUS
          check_number_operand(expr.operator, right)
          -right
        end
      end

      def visit_binary_expr(expr)
        left = evaluate(expr.left)
        right = evaluate(expr.right)

        case expr.operator.type
        when Rublox::Parser::TokenType::GREATER
          check_number_operands(expr.operator, left, right)
          left > right
        when Rublox::Parser::TokenType::GREATER_EQUAL
          check_number_operands(expr.operator, left, right)
          left >= right
        when Rublox::Parser::TokenType::LESS
          check_number_operands(expr.operator, left, right)
          left < right
        when Rublox::Parser::TokenType::LESS_EQUAL
          check_number_operands(expr.operator, left, right)
          left <= right
        when Rublox::Parser::TokenType::BANG_EQUAL
          !is_equal?(left, right)
        when Rublox::Parser::TokenType::EQUAL_EQUAL
          is_equal?(left, right)
        when Rublox::Parser::TokenType::MINUS
          check_number_operands(expr.operator, left, right)
          left - right
        when Rublox::Parser::TokenType::PLUS
          if (left.is_a?(Float) && right.is_a?(Float)) || (left.is_a?(String) && right.is_a?(String))
            return left + right
          end

          raise LoxRuntimeError.new(expr.operator, "Operands must be two numbers or two strings.")
        when Rublox::Parser::TokenType::SLASH
          check_number_operands(expr.operator, left, right)
          left / right
        when Rublox::Parser::TokenType::STAR
          check_number_operands(expr.operator, left, right)
          left * right
        end
      end

      def visit_call_expr(expr)
        callee = evaluate(expr.callee)

        arguments = expr.arguments.map(&method(:evaluate))

        if !callee.respond_to?(:arity) || !callee.respond_to?(:call)
          raise LoxRuntimeError.new(expr.paren, "Can only call functions and classes.")
        end

        if arguments.count != callee.arity
          raise LoxRuntimeError.new(expr.paren, "Expected #{callee.arity} arguments but got #{arguments.count}.")
        end

        callee.call(self, arguments)
      end

      def visit_get_expr(expr)
        object = evaluate(expr.object)
        if object.is_a?(LoxInstance)
          return object.get(expr.name)
        end

        raise LoxRuntimeError.new(expr.name, "Only instances have properties.")
      end

      def visit_set_expr(expr)
        object = evaluate(expr.object)

        if !object.is_a?(LoxInstance)
          raise LoxRuntimeError.new(expr.name, "Only instances have fields.")
        end

        value = evaluate(expr.value)
        object.set(expr.name, value)
        value
      end

      def visit_this_expr(expr)
        lookup_variable(expr.keyword, expr)
      end

      def visit_variable_expr(expr)
        lookup_variable(expr.name, expr)
      end

      def visit_assign_expr(expr)
        value = evaluate(expr.value)

        distance = @locals[expr.object_id]
        if !distance.nil?
          @environment.assign_at(distance, expr.name, value)
        else
          @globals.assign(expr.name, value)
        end

        value
      end

      def execute_block(statements, environment)
        previous = @environment

        begin
          @environment = environment
          statements.each { |statement| execute(statement) }
          nil
        ensure
          @environment = previous
        end
      end

      def resolve(expr, depth)
        # Using object_id to uniquely identify each expression regardless of its contents.
        # Using value objects like structs might have been a mistake...
        @locals[expr.object_id] = depth
      end

      private

      def execute(stmt)
        stmt.accept(self)
      end

      def evaluate(expr)
        expr.accept(self)
      end

      def lookup_variable(name, expr)
        distance = @locals[expr.object_id]
        if !distance.nil?
          @environment.get_at(distance, name.lexeme)
        else
          @globals.get(name)
        end
      end

      def is_truthy?(object)
        !object.nil? && object != false
      end

      def is_equal?(a, b)
        # Mostly trivial, but unlike the original, (0.0 / 0.0) == (0.0 / 0.0) actually follows IEEE 754
        a == b
      end

      def check_number_operand(operator, operand)
        return if operand.is_a?(Float)

        raise LoxRuntimeError.new(operator, "Operand must be a number.")
      end

      def check_number_operands(operator, left, right)
        return if left.is_a?(Float) && right.is_a?(Float)

        raise LoxRuntimeError.new(operator, "Operands must be numbers.")
      end

      def stringify(object)
        return "nil" if object.nil?

        if object.is_a?(Float)
          text = object.to_s
          if text.end_with?(".0")
            text = text[0...text.length - 2]
          end
          return text
        end

        object.to_s
      end
    end
  end
end
