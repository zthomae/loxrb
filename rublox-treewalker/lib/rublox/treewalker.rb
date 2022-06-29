# frozen_string_literal: true

require_relative "treewalker/lox_runtime_error"
require_relative "treewalker/runtime_return"
require_relative "treewalker/environment"
require_relative "treewalker/callable"
require_relative "treewalker/resolver"
require_relative "treewalker/interpreter"
require_relative "treewalker/main"
require_relative "treewalker/repl"
require_relative "treewalker/version"

module Rublox
  module TreeWalker
    class Error < StandardError; end
    # Your code goes here...
  end
end
