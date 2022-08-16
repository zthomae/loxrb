require "pathname"

module Lox
  module Test
    class Suite
      attr_reader :name, :language, :executable, :args, :tests, :passed, :failed, :skipped, :expectations

      TEST_CASES_DIR = File.join(File.dirname(__FILE__), "..", "cases").freeze

      def initialize(name, language, executable, args, tests)
        @name = name
        @language = language
        @executable = executable
        @args = args
        @tests = tests

        @passed = 0
        @failed = 0
        @skipped = 0
        @expectations = 0
      end

      def run(filter_path, custom_interpreter, custom_arguments)
        test_failures = {}

        Dir[File.join(TEST_CASES_DIR, "**", "**.lox")].each do |path|
          next if path.include?("benchmark")

          if !filter_path.nil?
            this_test = Pathname.new(path).relative_path_from(Pathname.new("test"))
            next unless this_test.start_with?(filter_path)
          end

          test = TestCase.new(self, path, custom_interpreter, custom_arguments)

          parse_result = test.parse
          @expectations += parse_result.expectations
          if parse_result.status == :skip
            @skipped += 1
            print("S")
          elsif parse_result.status == true
            failures = test.run
            if failures.nil? || failures.empty?
              @passed += 1
              print(".")
            else
              @failed += 1
              print("F")
              test_failures[path] = failures
            end
          end
        end

        puts ""

        if failed == 0
          puts "All #{passed} tests passed (#{expectations} expectations)."
        else
          test_failures.each do |path, failures|
            puts "FAIL #{path}"
            puts ""
            failures.each do |failure|
              puts "     #{failure}"
            end
            puts ""
          end

          puts "#{passed} tests passed. #{failed} tests failed."
        end

        failed == 0
      end
    end
  end
end
