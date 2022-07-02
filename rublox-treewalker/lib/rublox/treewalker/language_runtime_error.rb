module Rublox
  module TreeWalker
    class LanguageRuntimeError < StandardError
      attr_reader :token

      # Note: Always initialize with .new -- Ruby does strange things if the first parameter
      # isn't the message with more indirect ways of instantiating the error class. I've
      # chosen to match the book's parameter ordering to make it easier to translate.
      def initialize(token, message)
        super(message)
        @token = token
      end
    end
  end
end
