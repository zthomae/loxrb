# frozen_string_literal: true

RSpec.describe Rublox::Parser do
  it "has a version number" do
    expect(Rublox::Parser::VERSION).not_to be nil
  end

  it "scans lexemes" do
    error_handler = Class.new do
      def self.error(line, message)
        raise "found unexpected error on line #{line}: #{message}"
      end
    end

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
    tokens = Rublox::Parser::Scanner.new(source, error_handler).scan_tokens
    expect(tokens.map(&:to_h)).to match_snapshot("scans_lexemes")
  end
end
