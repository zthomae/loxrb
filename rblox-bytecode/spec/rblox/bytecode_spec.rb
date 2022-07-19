# frozen_string_literal: true

require "stringio"

RSpec.describe Rblox::Bytecode do
  it "has a version number" do
    expect(Rblox::Bytecode::VERSION).not_to be nil
  end

  subject { Rblox::Bytecode::Main.new }

  def write_simple_chunk(chunk)
    constant = Rblox::Bytecode.chunk_add_number(chunk, 1.2)
    Rblox::Bytecode.chunk_write(chunk, constant, 123)
    Rblox::Bytecode.chunk_write(chunk, :constant, 123)

    constant = Rblox::Bytecode.chunk_add_number(chunk, 3.4)
    Rblox::Bytecode.chunk_write(chunk, :constant, 123)
    Rblox::Bytecode.chunk_write(chunk, constant, 123)

    Rblox::Bytecode.chunk_write(chunk, :add, 123)

    constant = Rblox::Bytecode.chunk_add_number(chunk, 5.6)
    Rblox::Bytecode.chunk_write(chunk, :constant, 123)
    Rblox::Bytecode.chunk_write(chunk, constant, 123)

    Rblox::Bytecode.chunk_write(chunk, :divide, 123)

    Rblox::Bytecode.chunk_write(chunk, :negate, 123)
    Rblox::Bytecode.chunk_write(chunk, :return, 123)
  end

  it "disassembles simple chunks" do
    Rblox::Bytecode::Chunk.with_new do |chunk|
      write_simple_chunk(chunk)
      io = StringIO.new
      disassembler = Rblox::Bytecode::Disassembler.new(io)
      disassembler.disassemble_chunk(chunk, "test chunk")
      expect(io.string).to eq(
        <<~EOF
          == test chunk ==
          0000  123 OP_CONSTANT         0 '1.2'
          0002    | OP_CONSTANT         1 '3.4'
          0004    | OP_ADD
          0005    | OP_CONSTANT         2 '5.6'
          0007    | OP_DIVIDE
          0008    | OP_NEGATE
          0009    | OP_RETURN
        EOF
      )
    end
  end

  it "executes simple instructions one at a time" do
    Rblox::Bytecode::VM.with_new do |vm|
      disassembler = Rblox::Bytecode::Disassembler.new($stdout)

      Rblox::Bytecode::Chunk.with_new do |chunk|
        write_simple_chunk(chunk)
        Rblox::Bytecode.vm_init_chunk(vm, chunk)
        loop do
          disassembler.disassemble_instruction(chunk, vm.current_offset)
          interpret_result = Rblox::Bytecode.vm_interpret_next_instruction(vm)
          pp vm.stack_contents
          break if interpret_result != :incomplete
        end
      end
    end
  end

  it "executes simple instructions all at once" do
    Rblox::Bytecode::VM.with_new do |vm|
      Rblox::Bytecode::Chunk.with_new do |chunk|
        write_simple_chunk(chunk)
        Rblox::Bytecode.vm_interpret(vm, chunk)
      end
    end
  end

  it "executes simple arithmetic with Main in debug mode" do
    ["1 + 1;", "2 - 3;", "5 * 5;", "6 / 2;"].each do |expr|
      puts "evaluating '#{expr}' (debug mode)"
      subject.run(expr, debug_mode: true)
    end
  end

  it "executes simple arithmetic with Main" do
    ["1 + 1;", "2 - 3;", "5 * 5;", "6 / 2;"].each do |expr|
      puts "evaluating '#{expr}'"
      subject.run(expr, debug_mode: false)
    end
  end

  it "executes a more complex arithmetic expression with Main in debug mode" do
    subject.run("(5 - (3 - 1)) + -1;", debug_mode: true)
  end

  it "executes a more complex arithmetic expression with Main" do
    subject.run("(5 - (3 - 1)) + -1;", debug_mode: false)
  end

  it "executes a logical and arithmetic expression with Main in debug mode" do
    subject.run("!(5 - 4 > 3 * 2 == !nil);", debug_mode: true)
  end

  it "executes a logical and arithmetic expression with Main in" do
    subject.run("!(5 - 4 > 3 * 2 == !nil);", debug_mode: false)
  end
end
