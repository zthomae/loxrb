# frozen_string_literal: true

require_relative "bytecode/opcode"
require_relative "bytecode/chunk"
require_relative "bytecode/disassembler"
require_relative "bytecode/version"

module Rublox
  module Bytecode
    class Error < StandardError; end
    # Your code goes here...
  end
end
