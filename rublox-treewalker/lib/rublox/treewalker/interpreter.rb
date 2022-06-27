module Rublox
  module TreeWalker
    class Interpreter
      def initialize(error_handler)
        @error_handler = error_handler
        @environment = Environment.new
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

      def visit_expression_stmt(stmt)
        evaluate(stmt.expression)
        nil
      end

      def visit_print_stmt(stmt)
        value = evaluate(stmt.expression)
        puts stringify(value)
        nil
      end

      def visit_var_stmt(stmt)
        value = nil
        if !stmt.initializer.nil?
          value = evaluate(stmt.initializer)
        end

        @environment.define(stmt.name.lexeme, value)
        nil
      end

      def visit_literal_expr(expr)
        return expr.value
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

      def visit_variable_expr(expr)
        @environment.get(expr.name)
      end

      def visit_assign_expr(expr)
        value = evaluate(expr.value)
        @environment.assign(expr.name, value)
        value
      end

      private

      def execute(stmt)
        stmt.accept(self)
      end

      def execute_block(statements, environment)
        previous = @environment

        begin
          @environment = environment
          statements.each { |statement| execute(statement) }
        ensure
          @environment = previous
        end
      end

      def evaluate(expr)
        expr.accept(self)
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
