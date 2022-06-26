module Rublox
  module Parser
    Token = Struct.new(:type, :lexeme, :literal, :line, keyword_init: true) do
      def to_s
        "#{type} #{lexeme} #{literal.nil? ? "null" : literal}"
      end
    end
  end
end
