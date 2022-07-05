module Rblox
  module Parser
    Token = Struct.new(:type, :lexeme, :literal, :line) do
      def to_s
        "#{type} #{lexeme} #{literal.nil? ? "null" : literal}"
      end
    end
  end
end
