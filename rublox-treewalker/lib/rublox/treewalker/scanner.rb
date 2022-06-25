module Rublox
  module TreeWalker
    class Scanner
      def initialize(source)
        @source = source
      end

      def scan_tokens
        [@source]
      end
    end
  end
end
