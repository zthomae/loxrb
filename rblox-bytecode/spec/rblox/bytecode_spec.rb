# frozen_string_literal: true

require "stringio"

RSpec.describe Rblox::Bytecode do
  it "has a version number" do
    expect(Rblox::Bytecode::VERSION).not_to be nil
  end

  it "disassembles simple chunks" do
    FFI::MemoryPointer.new(Rblox::Bytecode::Chunk, 1) do |p|
      chunk = Rblox::Bytecode::Chunk.new(p[0])
      Rblox::Bytecode.chunk_init(chunk)
      constant = Rblox::Bytecode.chunk_add_constant(chunk, 1.2)
      Rblox::Bytecode.chunk_write(chunk, constant, 123)
      Rblox::Bytecode.chunk_write(chunk, :constant, 123)
      Rblox::Bytecode.chunk_write(chunk, :return, 123)
      io = StringIO.new
      disassembler = Rblox::Bytecode::Disassembler.new(io)
      disassembler.disassemble_chunk(chunk, "test chunk")
      Rblox::Bytecode.chunk_free(chunk)
      expect(io.string).to eq(
        <<~EOF
        == test chunk ==
        0000  123 OP_CONSTANT         0 '1.2'
        0002    | OP_RETURN
        EOF
      )
      expect(chunk[:count]).to eq(0)
    end
  end
end
