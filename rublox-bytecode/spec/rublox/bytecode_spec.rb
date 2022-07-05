# frozen_string_literal: true

require "stringio"

RSpec.describe Rublox::Bytecode do
  it "has a version number" do
    expect(Rublox::Bytecode::VERSION).not_to be nil
  end

  it "disassembles simple chunks" do
    FFI::MemoryPointer.new(Rublox::Bytecode::Chunk, 1) do |p|
      chunk = Rublox::Bytecode::Chunk.new(p[0])
      Rublox::Bytecode.chunk_init(chunk)
      constant = Rublox::Bytecode.chunk_add_constant(chunk, 1.2)
      Rublox::Bytecode.chunk_write(chunk, constant, 123)
      Rublox::Bytecode.chunk_write(chunk, :constant, 123)
      Rublox::Bytecode.chunk_write(chunk, :return, 123)
      io = StringIO.new
      disassembler = Rublox::Bytecode::Disassembler.new(io)
      disassembler.disassemble_chunk(chunk, "test chunk")
      Rublox::Bytecode.chunk_free(chunk)
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
