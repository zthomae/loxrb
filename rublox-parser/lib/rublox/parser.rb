# frozen_string_literal: true

require_relative "parser/token"
require_relative "parser/token_type"
require_relative "parser/scanner" # depends on token_type
require_relative "parser/version"

module Rublox
  module Parser
    class Error < StandardError; end
    # Your code goes here...
  end
end
