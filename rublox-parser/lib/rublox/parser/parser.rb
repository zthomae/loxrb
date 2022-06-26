module Rublox
  module Parser
    class Parser
      def initialize(tokens, error_handler)
        @tokens = tokens
        @current = 0
        @error_handler = error_handler
      end

      def parse
        expression
      rescue ::Rublox::Parser::Error
        return nil
      end

      private

      def expression
        equality
      end

      def equality
        expr = comparison

        while match?(TokenType::BANG_EQUAL, TokenType::EQUAL_EQUAL)
          operator = previous
          right = comparison
          expr = Expr::Binary.new(expr, operator, right)
        end

        expr
      end

      def comparison
        expr = term

        while match?(TokenType::GREATER, TokenType::GREATER_EQUAL, TokenType::LESS, TokenType::LESS_EQUAL)
          operator = previous
          right = term
          expr = Expr::Binary.new(expr, operator, right)
        end

        expr
      end

      def term
        expr = factor

        while match?(TokenType::MINUS, TokenType::PLUS)
          operator = previous
          right = factor
          expr = Expr::Binary.new(expr, operator, right)
        end

        expr
      end

      def factor
        expr = unary

        while match?(TokenType::SLASH, TokenType::STAR)
          operator = previous
          right = unary
          expr = Expr::Binary.new(expr, operator, right)
        end

        expr
      end

      def unary
        if match?(TokenType::BANG, TokenType::MINUS)
          operator = previous
          right = unary
          return Expr::Unary.new(operator, right)
        end

        primary
      end

      def primary
        return Expr::Literal.new(false) if match?(TokenType::FALSE)
        return Expr::Literal.new(true) if match?(TokenType::TRUE)
        return Expr::Literal.new(nil) if match?(TokenType::NIL)

        if match?(TokenType::NUMBER, TokenType::STRING)
          return Expr::Literal.new(previous.literal)
        end

        if match?(TokenType::LEFT_PAREN)
          expr = expression
          consume(TokenType::RIGHT_PAREN, "Expect ')' after expression.")
          return Expr::Grouping.new(expr)
        end

        raise error(peek, "Expect expression.")
      end

      def match?(*types)
        types.each do |type|
          if check?(type)
            advance
            return true
          end
        end

        false
      end

      def consume(type, message)
        return advance if check?(type)

        raise error(peek, message)
      end

      def check?(type)
        return false if is_at_end?

        peek.type == type
      end

      def advance
        if !is_at_end?
          @current += 1
        end

        previous
      end

      def is_at_end?
        peek.type == TokenType::EOF
      end

      def peek
        @tokens[@current]
      end

      def previous
        @tokens[@current - 1]
      end

      def error(token, message)
        @error_handler.parse_error(token, message)
        ::Rublox::Parser::Error.new
      end

      def synchronize
        advance

        while !is_at_end?
          return if previous.type == TokenType::SEMICOLON

          case peek.type
          when TokenType::CLASS, TokenType::FUN, TokenType::VAR, TokenType::FOR, TokenType::IF, TokenType::WHILE, TokenType::PRINT, TokenType::RETURN
            return
          end

          advance
        end
      end
    end
  end
end
