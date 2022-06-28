module Rublox
  module Parser
    class RecursiveDescentParser
      def initialize(tokens, error_handler)
        @tokens = tokens
        @current = 0
        @error_handler = error_handler
      end

      def parse!
        statements = []
        while !is_at_end?
          statements << declaration!
        end

        statements
      end

      private

      def declaration!
        return var_declaration! if match!(TokenType::VAR)

        statement!
      rescue ::Rublox::Parser::Error
        synchronize!
        nil
      end

      def var_declaration!
        name = consume!(TokenType::IDENTIFIER, "Expect variable name.")

        initializer = nil
        if match!(TokenType::EQUAL)
          initializer = expression!
        end

        consume!(TokenType::SEMICOLON, "Expect ';' after variable declaration.")
        Stmt::Var.new(name, initializer)
      end

      def statement!
        return if_statement! if match!(TokenType::IF)
        return print_statement! if match!(TokenType::PRINT)
        return Stmt::Block.new(block!) if match!(TokenType::LEFT_BRACE)

        expression_statement!
      end

      def if_statement!
        consume!(TokenType::LEFT_PAREN, "Expect '(' after 'if'.")
        condition = expression!
        consume!(TokenType::RIGHT_PAREN, "Expect ')' after if condition.")

        then_branch = statement!
        if match!(TokenType::ELSE)
          else_branch = statement!
        end

        Stmt::If.new(condition, then_branch, else_branch)
      end

      def print_statement!
        value = expression!
        consume!(TokenType::SEMICOLON, "Expect ';' after value.")
        Stmt::Print.new(value)
      end

      def expression_statement!
        expr = expression!
        consume!(TokenType::SEMICOLON, "Expect ';' after expression.")
        Stmt::Expression.new(expr)
      end

      def block!
        statements = []

        while !check?(TokenType::RIGHT_BRACE) && !is_at_end?
          statements << declaration!
        end

        consume!(TokenType::RIGHT_BRACE, "Expect '}' after block.")
        statements
      end

      def expression!
        assignment!
      end

      def assignment!
        expr = equality!

        if match!(TokenType::EQUAL)
          equals = previous
          value = assignment!

          if expr.is_a?(Expr::Variable)
            name = expr.name
            return Expr::Assign.new(name, value)
          end

          error(equals, "Invalid assignment target.")
        end

        expr
      end

      def equality!
        expr = comparison!

        while match!(TokenType::BANG_EQUAL, TokenType::EQUAL_EQUAL)
          operator = previous
          right = comparison!
          expr = Expr::Binary.new(expr, operator, right)
        end

        expr
      end

      def comparison!
        expr = term!

        while match!(TokenType::GREATER, TokenType::GREATER_EQUAL, TokenType::LESS, TokenType::LESS_EQUAL)
          operator = previous
          right = term!
          expr = Expr::Binary.new(expr, operator, right)
        end

        expr
      end

      def term!
        expr = factor!

        while match!(TokenType::MINUS, TokenType::PLUS)
          operator = previous
          right = factor!
          expr = Expr::Binary.new(expr, operator, right)
        end

        expr
      end

      def factor!
        expr = unary!

        while match!(TokenType::SLASH, TokenType::STAR)
          operator = previous
          right = unary!
          expr = Expr::Binary.new(expr, operator, right)
        end

        expr
      end

      def unary!
        if match!(TokenType::BANG, TokenType::MINUS)
          operator = previous
          right = unary!
          return Expr::Unary.new(operator, right)
        end

        primary!
      end

      def primary!
        return Expr::Literal.new(false) if match!(TokenType::FALSE)
        return Expr::Literal.new(true) if match!(TokenType::TRUE)
        return Expr::Literal.new(nil) if match!(TokenType::NIL)

        if match!(TokenType::NUMBER, TokenType::STRING)
          return Expr::Literal.new(previous.literal)
        end

        if match!(TokenType::IDENTIFIER)
          return Expr::Variable.new(previous)
        end

        if match!(TokenType::LEFT_PAREN)
          expr = expression!
          consume!(TokenType::RIGHT_PAREN, "Expect ')' after expression.")
          return Expr::Grouping.new(expr)
        end

        raise error(peek, "Expect expression.")
      end

      def match!(*types)
        types.each do |type|
          if check?(type)
            advance!
            return true
          end
        end

        false
      end

      def consume!(type, message)
        return advance! if check?(type)

        raise error(peek, message)
      end

      def check?(type)
        return false if is_at_end?

        peek.type == type
      end

      def advance!
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

      def synchronize!
        advance!

        while !is_at_end?
          return if previous.type == TokenType::SEMICOLON

          case peek.type
          when TokenType::CLASS, TokenType::FUN, TokenType::VAR, TokenType::FOR, TokenType::IF, TokenType::WHILE, TokenType::PRINT, TokenType::RETURN
            return
          end

          advance!
        end
      end
    end
  end
end
