module Lox
  module Parser
    Token = Struct.new(:type, :lexeme, :literal, :line) do
      def to_s
        "#{type} #{lexeme} #{literal.nil? ? "null" : literal}"
      end

      def bounding_lines
        [line, line]
      end
    end
  end
end
