module Rublox
  module TreeWalker
    class Interpreter
      class LoxRuntimeError < StandardError
        attr_reader :token

        # Note: Always initialize with .new -- Ruby does strange things if the first parameter
        # isn't the message with more indirect ways of instantiating the error class. I've
        # chosen to match the book's parameter ordering to make it easier to translate.
        def initialize(token, message)
          super(message)
          @token = token
        end
      end

      def initialize(error_handler)
        @error_handler = error_handler
      end

      def interpret(expression)
        value = evaluate(expression)
        puts stringify(value)
      rescue LoxRuntimeError => e
        @error_handler.runtime_error(e)
      end

      def visit_literal(expr)
        return expr.value
      end

      def visit_grouping(expr)
        evaluate(expr.expression)
      end

      def visit_unary(expr)
        right = evaluate(expr.right)

        case expr.operator.type
        when Rublox::Parser::TokenType::BANG
          !is_truthy?(right)
        when Rublox::Parser::TokenType::MINUS
          check_number_operand(expr.operator, right)
          -right
        end
      end

      def visit_binary(expr)
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

          raise LoxRuntimeError.new(expr.operator, "Operands must be two number or two strings.")
        when Rublox::Parser::TokenType::SLASH
          check_number_operands(expr.operator, left, right)
          left / right
        when Rublox::Parser::TokenType::STAR
          check_number_operands(expr.operator, left, right)
          left * right
        end
      end

      private

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
