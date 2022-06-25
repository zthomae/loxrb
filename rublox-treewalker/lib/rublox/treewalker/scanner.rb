module Rublox
  module TreeWalker
    class Scanner
      def initialize(source)
        @source = source
        @tokens = []
        @start = 0
        @current = 0
        @line = 1
      end

      def scan_tokens
        while !is_at_end?
          @start = @current
          scan_token
        end

        @tokens << Token.new(type: TokenType::EOF, lexeme: "", literal: nil, line: @line)
        @tokens
      end

      private

      def is_at_end?
        @current >= @source.length
      end

      def scan_token
        c = advance
        case c
        when "("
          add_token(TokenType::LEFT_PAREN)
        when ")"
          add_token(TokenType::RIGHT_PAREN)
        when "{"
          add_token(TokenType::LEFT_BRACE)
        when "}"
          add_token(TokenType::RIGHT_BRACE)
        when ","
          add_token(TokenType::COMMA)
        when "."
          add_token(TokenType::DOT)
        when "-"
          add_token(TokenType::MINUS)
        when "+"
          add_token(TokenType::PLUS)
        when ";"
          add_token(TokenType::SEMICOLON)
        when "*"
          add_token(TokenType::STAR)

        when "!"
          add_token(match?("=") ? TokenType::BANG_EQUAL : TokenType::BANG)
        when "="
          add_token(match?("=") ? TokenType::EQUAL_EQUAL : TokenType::EQUAL)
        when "<"
          add_token(match?("=") ? TokenType::LESS_EQUAL : TokenType::LESS)
        when ">"
          add_token(match?("=") ? TokenType::GREATER_EQUAL : TokenType::GREATER)

        when "/"
          if match?("/")
            while peek != "\n" && !is_at_end?
              advance
            end
          else
            add_token(TokenType::SLASH)
          end

        when " ", "\r", "\t"
          # Ignore non-newline whitespace characters
        when "\n"
          @line += 1

        else
          Interpreter.error(@line, "Unexpected character.")
        end
      end

      def advance
        c = @source[@current]
        @current += 1
        c
      end

      # Note: Possibly a little bit strange that this is a predicate method that also modifies state
      def match?(expected)
        return false if is_at_end?
        return false if @source[@current] != expected

        @current += 1
        true
      end

      def peek
        return if is_at_end? # NOTE: Book returns the zero character...
        @source[@current]
      end

      def add_token(type, literal = nil)
        text = @source[@start...@current]
        @tokens << Token.new(type: type, lexeme: text, literal: literal, line: @line)
      end
    end
  end
end
