# frozen_string_literal: true

require_relative "treewalker/interpreter"
require_relative "treewalker/repl"
require_relative "treewalker/token"
require_relative "treewalker/token_type"
require_relative "treewalker/scanner" # depends on token_type
require_relative "treewalker/version"

module Rublox
  module TreeWalker
    class Error < StandardError; end
    # Your code goes here...
  end
end
