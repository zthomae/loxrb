# frozen_string_literal: true

RSpec.describe Rublox::Parser do
  it "has a version number" do
    expect(Rublox::Parser::VERSION).not_to be nil
  end

  # TODO: Remove interpreter references from parser
  class Interpreter
    def self.error(line, message)
      puts line, message
    end
  end

  it "scans lexemes" do
    source = <<~EOF
    class Foo {
      inFoo() {
        print "in foo";
      }
    }

    class Bar < Foo {
      inBar(a, b) {
        var a = 12.3;
        var b = .23;
        print nil;
      }
    }

    class Baz < Bar {
      inBaz() {
        print 1+2 / 3;
      }
    }

    var baz = Baz();
    EOF
    tokens = Rublox::Parser::Scanner.new(source).scan_tokens
    expect(tokens.map(&:to_h)).to match_snapshot("scans_lexemes")
  end
end
