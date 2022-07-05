module Rblox
  module Parser
    module TokenType
      @token_types = []

      def self.define_tokens(*tokens)
        tokens.each do |token|
          const_set(token, token)
          @token_types << token
        end
      end

      def self.token_types
        @token_types.dup
      end

      # Single-character tokens
      define_tokens(
        :LEFT_PAREN, :RIGHT_PAREN, :LEFT_BRACE, :RIGHT_BRACE,
        :COMMA, :DOT, :MINUS, :PLUS, :SEMICOLON, :SLASH, :STAR
      )

      # One or two character tokens
      define_tokens(
        :BANG, :BANG_EQUAL,
        :EQUAL, :EQUAL_EQUAL,
        :GREATER, :GREATER_EQUAL,
        :LESS, :LESS_EQUAL
      )

      # Literals
      define_tokens(:IDENTIFIER, :STRING, :NUMBER)

      # Keywords
      define_tokens(
        :AND, :CLASS, :ELSE, :FALSE, :FUN, :FOR, :IF, :NIL, :OR,
        :PRINT, :RETURN, :SUPER, :THIS, :TRUE, :VAR, :WHILE
      )

      define_tokens :EOF
    end
  end
end
