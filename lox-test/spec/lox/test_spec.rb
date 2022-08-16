# frozen_string_literal: true

RSpec.describe Lox::Test do
  it "has a version number" do
    expect(Lox::Test::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
