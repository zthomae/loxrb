# frozen_string_literal: true

require "stringio"

RSpec.describe Rblox::Bytecode do
  it "has a version number" do
    expect(Rblox::Bytecode::VERSION).not_to be nil
  end

  subject { Rblox::Bytecode::Main.new }

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

  it "repeatedly runs no-ops" do
    10.times do
      expect { subject.run("") }.not_to raise_error
    end
  end
end
