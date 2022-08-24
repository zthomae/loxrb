# frozen_string_literal: true

RSpec.describe Lox::Parser do
  before(:all) do
    @error_handler = Class.new do
      def self.scan_error(line, message)
        raise "found unexpected error on line #{line}: #{message}"
      end

      def self.parse_error(token, message)
        raise "found unexpected error on token #{token}: #{message}"
      end
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
    tokens = Lox::Parser::Scanner.new(source, @error_handler).scan_tokens
    expect(tokens.map(&:to_h)).to match_snapshot("scans_lexemes")
  end

  it "parses a simple mathematical expression" do
    source = "(1 > 2.4) == (5 < \"hello\");"
    tokens = Lox::Parser::Scanner.new(source, @error_handler).scan_tokens
    statements = Lox::Parser::RecursiveDescentParser.new(tokens, @error_handler).parse!
    printed_expressions = statements.map do |statement|
      Lox::Parser::AstPrinter.new.print(statement.expression)
    end
    expect(printed_expressions).to eq(["(== (group (> 1.0 2.4)) (group (< 5.0 \"hello\")))"])
  end

  it "parses multiple statements" do
    source = <<~EOF
      "hello" + " " + "world";
      print "done";
    EOF
    tokens = Lox::Parser::Scanner.new(source, @error_handler).scan_tokens
    statements = Lox::Parser::RecursiveDescentParser.new(tokens, @error_handler).parse!
    printed_expressions = statements.map do |statement|
      Lox::Parser::AstPrinter.new.print(statement)
    end
    expect(printed_expressions).to eq([
      "(+ (+ \"hello\" \" \") \"world\");",
      "print \"done\";"
    ])
  end

  it "captures line numbers" do
    source = <<~EOF
      "hello" + " " +
        "world";
      print 1;
    EOF
    tokens = Lox::Parser::Scanner.new(source, @error_handler).scan_tokens
    statements = Lox::Parser::RecursiveDescentParser.new(tokens, @error_handler).parse!
    expect(statements.map(&:bounding_lines)).to eq([[1, 2], [3, 3]])
  end
end
