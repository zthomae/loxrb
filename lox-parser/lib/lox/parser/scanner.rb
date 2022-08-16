module Lox
  module Parser
    class Scanner
      KEYWORDS = {
        "and" => TokenType::AND,
        "class" => TokenType::CLASS,
        "else" => TokenType::ELSE,
        "false" => TokenType::FALSE,
        "for" => TokenType::FOR,
        "fun" => TokenType::FUN,
        "if" => TokenType::IF,
        "nil" => TokenType::NIL,
        "or" => TokenType::OR,
        "print" => TokenType::PRINT,
        "return" => TokenType::RETURN,
        "super" => TokenType::SUPER,
        "this" => TokenType::THIS,
        "true" => TokenType::TRUE,
        "var" => TokenType::VAR,
        "while" => TokenType::WHILE
      }

      def initialize(source, error_handler)
        @source = source
        @tokens = []
        @start = 0
        @current = 0
        @line = 1
        @error_handler = error_handler
      end

      def scan_tokens
        until is_at_end?
          @start = @current
          scan_token
        end

        @tokens << Token.new(TokenType::EOF, "", nil, @line)
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

        when "\""
          scan_string

        else
          if is_digit?(c)
            scan_number
          elsif is_alpha?(c)
            scan_identifier
          else
            @error_handler.scan_error(@line, "Unexpected character.")
          end
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

      def peek_next
        return if @current + 1 >= @source.length
        @source[@current + 1]
      end

      def add_token(type, literal = nil)
        text = @source[@start...@current]
        @tokens << Token.new(type, text, literal, @line)
      end

      def scan_string
        while peek != '"' && !is_at_end?
          @line += 1 if peek == "\n"
          advance
        end

        if is_at_end?
          @error_handler.scan_error(@line, "Unterminated string.")
          return
        end

        # The closing "
        advance

        # Trim surrounding quotes
        value = @source[@start + 1...@current - 1]
        add_token(TokenType::STRING, value)
      end

      def scan_number
        while is_digit?(peek)
          advance
        end

        # Look for a fractional part
        if peek == "." && is_digit?(peek_next)
          # Consume the .
          advance

          while is_digit?(peek)
            advance
          end
        end

        add_token(TokenType::NUMBER, Float(@source[@start...@current]))
      end

      def scan_identifier
        while is_alpha_numeric?(peek)
          advance
        end

        text = @source[@start...@current]
        token_type = KEYWORDS[text] || TokenType::IDENTIFIER
        add_token(token_type)
      end

      def is_digit?(c)
        return false if c.nil?

        c = c[0]
        c >= "0" && c <= "9"
      end

      def is_alpha?(c)
        return false if c.nil?

        c = c[0]
        (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c == "_")
      end

      def is_alpha_numeric?(c)
        is_digit?(c) || is_alpha?(c)
      end
    end
  end
end
