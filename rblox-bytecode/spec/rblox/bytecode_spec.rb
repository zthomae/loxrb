# frozen_string_literal: true

require "stringio"

RSpec.describe Rblox::Bytecode do
  it "has a version number" do
    expect(Rblox::Bytecode::VERSION).not_to be nil
  end

  subject { Rblox::Bytecode::Main }

  let(:default_options) do
    Rblox::Bytecode::Main::VmOptions.new(
      log_disassembly: false,
      log_gc: false,
      stress_gc: false
    )
  end

  let(:debug_options) do
    Rblox::Bytecode::Main::VmOptions.new(
      log_disassembly: true,
      log_gc: false,
      stress_gc: false
    )
  end

  it "executes simple arithmetic with Main in debug mode" do
    ["1 + 1;", "2 - 3;", "5 * 5;", "6 / 2;"].each do |expr|
      puts "evaluating '#{expr}' (debug mode)"
      subject.new(debug_options).run(expr)
    end
  end

  it "executes simple arithmetic with Main" do
    ["1 + 1;", "2 - 3;", "5 * 5;", "6 / 2;"].each do |expr|
      puts "evaluating '#{expr}'"
      subject.new(default_options).run(expr)
    end
  end

  it "executes a more complex arithmetic expression with Main in debug mode" do
    subject.new(debug_options).run("(5 - (3 - 1)) + -1;")
  end

  it "executes a more complex arithmetic expression with Main" do
    subject.new(default_options).run("(5 - (3 - 1)) + -1;")
  end

  it "executes a logical and arithmetic expression with Main in debug mode" do
    subject.new(debug_options).run("!(5 - 4 > 3 * 2 == !nil);")
  end

  it "executes a logical and arithmetic expression with Main in" do
    subject.new(default_options).run("!(5 - 4 > 3 * 2 == !nil);")
  end

  it "repeatedly runs no-ops" do
    10.times do
      expect { subject.new.run("") }.not_to raise_error
    end
  end
end
