require "open3"
require "set"

module Rublox
  module Test
    class TestCase
      module OutputPatterns
        EXPECTED_OUTPUT = /\/\/ expect: ?(.*)/
        EXPECTED_ERROR = /\/\/ (Error.*)/
        ERROR_LINE = /\/\/ \[((java|c) )?line (\d+)\] (Error.*)/
        EXPECTED_RUNTIME_ERROR = /\/\/ expect runtime error: (.+)/
        SYNTAX_ERROR = /\[.*line (\d+)\] (Error.+)/
        STACK_TRACE = /\[line (\d+)\]/
        NONTEST = /\/\/ nontest/
      end

      ExpectedOutput = Struct.new(:line, :output)

      TestParseOutput = Struct.new(:status, :expectations)

      def initialize(suite, path, custom_interpreter, custom_arguments)
        @suite = suite
        @path = path
        @custom_interpreter = custom_interpreter
        @custom_arguments = custom_arguments
        @expected_output = []
        @expected_errors = Set.new
        @failures = []

        # Do I need these in the constructor?
        @expected_runtime_error = nil
        @runtime_error_line = 0
        @expected_exit_code = 0
      end

      def parse
        test_case_path = @path.sub("#{Rublox::Test::Suite::TEST_CASES_DIR}/", "test/")
        parts = test_case_path.split("/")
        subpath = ""
        state = nil
        expectations = 0

        parts.each do |part|
          subpath += "/" if !subpath.empty?
          subpath += part

          if @suite.tests.include?(subpath)
            state = @suite.tests[subpath]
          end
        end

        if state.nil?
          raise "Unknown test state for #{test_case_path}"
        elsif state == "skip"
          return TestParseOutput.new(:skip, expectations)
        end

        lines = File.readlines(@path)
        (1..lines.length).each do |line_num|
          line = lines[line_num - 1]
          match = OutputPatterns::NONTEST.match(line)
          if !match.nil?
            return TestParseOutput.new(false, expectations)
          end
          return TestParseOutput.new(false, expectations) if !match.nil?

          match = OutputPatterns::EXPECTED_OUTPUT.match(line)
          if !match.nil?
            @expected_output << ExpectedOutput.new(line_num, match[1])
            expectations += 1
            next
          end

          match = OutputPatterns::EXPECTED_ERROR.match(line)
          if !match.nil?
            @expected_errors << "[#{line_num}] #{match[1]}"

            # If we expect a compile error, it should exit with EX_DATAERR
            @expected_exit_code = 65
            expectations += 1
            next
          end

          match = OutputPatterns::ERROR_LINE.match(line)
          if !match.nil?
            # The two interpreters are slightly different in terms of which
            # cascaded errors may appear after an initial compile error because
            # their panic mode recovery is a little different. To handle that,
            # the tests can indicate if an error line should only appear for a
            # certain interpreter.

            language = match[2]
            if language.nil? || language == @suite.language
              @expected_errors << "[#{match[3]}] #{match[4]}"

              # If we expect a compile error, it should exit with EX_DATAERR
              @expected_exit_code = 65
              expectations += 1
            end

            next
          end

          match = OutputPatterns::EXPECTED_RUNTIME_ERROR.match(line)
          if !match.nil?
            @runtime_error_line = line_num
            @expected_runtime_error = match[1]
            # If we expect a runtime error, it should exit with EX_SOFTWARE
            @expected_exit_code = 70
            expectations += 1
          end
        end

        if !@expected_errors.empty? && !@expected_runtime_error.nil?
          puts "TEST ERROR #{@path}"
          puts "     Cannot expect both compile and runtime errors"
          puts ""
          return TestParseOutput.new(false, expectations)
        end

        # If we got here, it's a valid test
        TestParseOutput.new(true, expectations)
      end

      def run
        args = if @custom_interpreter.nil?
          @suite.args.dup
        else
          @custom_arguments.dup
        end
        args << @path
        stdout_str, stderr_str, status = Open3.capture3("#{@custom_interpreter || @suite.executable} #{args.join(" ")}".strip)

        output_lines = stdout_str.split(/\r?\n/)
        error_lines = stderr_str.split(/\r?\n/)

        if !@expected_runtime_error.nil?
          validate_runtime_error(error_lines)
        else
          validate_compile_errors(error_lines)
        end

        validate_exit_code(status.exitstatus, error_lines)
        validate_output(output_lines)
        return @failures
      end

      def validate_runtime_error(error_lines)
        if error_lines.length < 2
          fail("Expected runtime error '#{@expected_runtime_error}' and got none.")
          return
        end

        if error_lines[0] != @expected_runtime_error
          fail("Expected runtime error '#{@expected_runtime_error}' and got:")
          fail(error_lines[0])
        end

        match = nil
        stack_lines = error_lines.drop(1)
        stack_lines.each do |line|
          match = OutputPatterns::STACK_TRACE.match(line)
          break if !match.nil?
        end

        if match.nil?
          fail("Expcted stack trace and got:", stack_lines)
        else
          stack_line = match[1].to_i
          if stack_line != @runtime_error_line
            fail("Expected runtime error on line #{@runtime_error_line} but was on line #{stack_line}.")
          end
        end
      end

      def validate_compile_errors(error_lines)
        found_errors = Set.new
        unexpected_count = 0
        error_lines.each do |line|
          match = OutputPatterns::SYNTAX_ERROR.match(line)
          if !match.nil?
            error = "[#{match[1]}] #{match[2]}"
            if @expected_errors.include?(error)
              found_errors.add(error)
            else
              if unexpected_count < 10
                fail("Unexpected error:")
                fail(line)
              end
              unexpected_count += 1
            end
          elsif line != ""
            if unexpected_count < 10
              fail("Unexpected output on stderr:")
              fail(line)
            end
            unexpected_count += 1
          end
        end

        if unexpected_count > 10
          fail("(truncated #{unexpected_count - 10} more...")
        end

        (@expected_errors - found_errors).each do |error|
          fail("Missing expected error: #{error}")
        end
      end

      def validate_exit_code(exit_code, error_lines)
        return if exit_code == @expected_exit_code

        if error_lines.length > 10
          error_lines = error_lines.take(10)
          error_lines << "(truncated...)"
        end

        fail("Expected return code #{@expected_exit_code} but got #{exit_code}. Stderr:", error_lines)
      end

      def validate_output(output_lines)
        # Remove the trailing last empty line
        if !output_lines.empty? && output_lines.last == ""
          output_lines.pop
        end

        index = 0
        while index < output_lines.length
          line = output_lines[index]
          if index >= @expected_output.length
            fail("Got output '#{line}' when none was expected.")
            index += 1
            next
          end

          expected = @expected_output[index]
          if expected.output != line
            fail("Expected output '#{expected.output}' on line #{expected.line} and got '#{line}'.")
          end

          index += 1
        end

        while index < @expected_output.length
          expected = @expected_output[index]
          fail("Missing expected output '#{expected.output}' on line #{expected.line}.")
          index += 1
        end
      end

      def fail(message, lines = nil)
        @failures << message
        if !lines.nil?
          @failures.append(*lines)
        end
      end
    end
  end
end
