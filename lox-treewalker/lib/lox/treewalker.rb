# frozen_string_literal: true

require_relative "treewalker/language_runtime_error"
require_relative "treewalker/runtime_return"
require_relative "treewalker/environment"
require_relative "treewalker/native_function"
require_relative "treewalker/user_defined_function"
require_relative "treewalker/user_defined_class"
require_relative "treewalker/user_defined_class_instance"
require_relative "treewalker/resolver"
require_relative "treewalker/interpreter"
require_relative "treewalker/main"
require_relative "treewalker/repl"
require_relative "treewalker/version"

module Lox
  module TreeWalker
    class Error < StandardError; end
    # Your code goes here...
  end
end
