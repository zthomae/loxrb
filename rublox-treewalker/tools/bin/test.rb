require "open3"
require "optparse"
require "pathname"
require "set"

class Suite
  attr_reader :name, :language, :executable, :args, :tests, :passed, :failed, :skipped, :expectations

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

    Dir["test/**/**.lox"].each do |path|
      next if path.include?("benchmark")

      # TODO: Normalize path?

      if !filter_path.nil?
        this_test = Pathname.new(path).relative_path_from(Pathname.new("test"))
        next if !this_test.start_with?(filter_path)
      end

      test = Test.new(self, path, custom_interpreter, custom_arguments)

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

    return failed == 0
  end
end

USAGE = "Usage: test.rb <suites> [filter] [custom interpreter...]"

def main
  test_collection = TestCollection.new

  options = {}
  OptionParser.new do |opts|
    opts.banner = USAGE

    opts.on("-i", "--interpreter INTERPRETER", "Path to interpreter") do |interpreter|
      options[:interpreter] = interpreter
    end

    # TODO: Not quite equivalent to the original
    opts.on("-a", "--arguments x,y,z", Array, "Additional interpreter arguments") do |arguments|
      options[:arguments] = arguments
    end
  end.parse!

  if ARGV.empty?
    usage_error("Missing suite name")
  elsif ARGV.length > 2
    usage_error("Unexpected arguments: #{ASRGV.drop(2).join(' ')}")
  end

  suite_name = ARGV[0]
  filter_path = ARGV[1] if ARGV.length == 2

  if options[:interpreter]
    custom_interpreter = options[:interpreter]
  end

  if options[:arguments]
    custom_arguments = options[:arguments]

    if custom_interpreter.nil?
      usage_error("Must pass an interpreter path if providing custom arguments")
    end
  end

  if suite_name == "all"
    run_suites(test_collection.all_suites, filter_path, custom_interpreter, custom_arguments)
  elsif suite_name == "c"
    run_suites(test_collection.c_suites, filter_path, custom_interpreter, custom_arguments)
  elsif suite_name == "java"
    run_suites(test_collection.java_suites, filter_path, custom_interpreter, custom_arguments)
  elsif !test_collection.contains_suite?(suite_name)
    puts "Unknown interpreter '#{suite_name}'"
    exit 1
  elsif !run_suite(test_collection.suite(suite_name), filter_path, custom_interpreter, custom_arguments)
    exit 1
  end
end

def usage_error(message)
  puts message
  puts ""
  puts USAGE
  exit 1
end

def run_suites(suites, filter_path, custom_interpreter, custom_arguments)
  any_failed = false
  suites.each do |name, suite|
    puts "=== #{name} ==="
    any_failed = true if !run_suite(suite, filter_path, custom_interpreter, custom_arguments)
    puts ""
  end

  exit(1) if any_failed
end

def run_suite(suite, filter_path, custom_interpreter, custom_arguments)
  suite.run(filter_path, custom_interpreter, custom_arguments)
end

ExpectedOutput = Struct.new(:line, :output)

TestParseOutput = Struct.new(:status, :expectations)

class Test
  module OutputPatterns
    EXPECTED_OUTPUT = /\/\/ expect: ?(.*)/
    EXPECTED_ERROR = /\/\/ (Error.*)/
    ERROR_LINE = /\/\/ \[((java|c) )?line (\d+)\] (Error.*)/
    EXPECTED_RUNTIME_ERROR = /\/\/ expect runtime error: (.+)/
    SYNTAX_ERROR = /\[.*line (\d+)\] (Error.+)/
    STACK_TRACE = /\[line (\d+)\]/
    NONTEST = /\/\/ nontest/
  end

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
    parts = @path.split("/")
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
      raise "Unknown test state for #{@path}"
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

class TestCollection
  def initialize
    @all_suites = {}
    @c_suites = []
    @java_suites = []
    define_test_suites
  end

  def all_suites
    @all_suites.dup
  end

  def c_suites
    @all_suites.slice(*@c_suites)
  end

  def java_suites
    @all_suites.slice(*@java_suites)
  end

  def contains_suite?(suite_name)
    @all_suites.include?(suite_name)
  end

  def suite(suite_name)
    @all_suites[suite_name]
  end

  private

  def define_test_suites
    c = ->(name, tests) do
      executable = name == "clox" ? "build/cloxd" : "build/#{name}"
      @all_suites[name] = Suite.new(name, "c", executable, [], tests)
      @c_suites.append(name)
    end

    java = ->(name, tests) do
      dir = name == "jlox" ? "build/java" : "build/gen/#{name}"
      @all_suites[name] = Suite.new(name, "java", "exe/rublox-treewalker", [], tests)
      @java_suites.append(name)
    end

    early_chapters = {
      "test/scanning" => "skip",
      "test/expressions" => "skip",
    }

    java_NaN_equality = {
      "test/number/nan_equality.lox" => "skip",
    }

    no_java_limits = {
      "test/limit/loop_too_large.lox" => "skip",
      "test/limit/no_reuse_constants.lox" => "skip",
      "test/limit/too_many_constants.lox" => "skip",
      "test/limit/too_many_locals.lox" => "skip",
      "test/limit/too_many_upvalues.lox" => "skip",

      # Rely on JVM for stack overflow checking.
      "test/limit/stack_overflow.lox" => "skip",
    }

    no_java_classes = {
      "test/assignment/to_this.lox" => "skip",
      "test/call/object.lox" => "skip",
      "test/class" => "skip",
      "test/closure/close_over_method_parameter.lox" => "skip",
      "test/constructor" => "skip",
      "test/field" => "skip",
      "test/inheritance" => "skip",
      "test/method" => "skip",
      "test/number/decimal_point_at_eof.lox" => "skip",
      "test/number/trailing_dot.lox" => "skip",
      "test/operator/equals_class.lox" => "skip",
      "test/operator/equals_method.lox" => "skip",
      "test/operator/not_class.lox" => "skip",
      "test/regression/394.lox" => "skip",
      "test/super" => "skip",
      "test/this" => "skip",
      "test/return/in_method.lox" => "skip",
      "test/variable/local_from_method.lox" => "skip",
    }

    no_java_functions = {
      "test/call" => "skip",
      "test/closure" => "skip",
      "test/for/closure_in_body.lox" => "skip",
      "test/for/return_closure.lox" => "skip",
      "test/for/return_inside.lox" => "skip",
      "test/for/syntax.lox" => "skip",
      "test/function" => "skip",
      "test/operator/not.lox" => "skip",
      "test/regression/40.lox" => "skip",
      "test/return" => "skip",
      "test/unexpected_character.lox" => "skip",
      "test/while/closure_in_body.lox" => "skip",
      "test/while/return_closure.lox" => "skip",
      "test/while/return_inside.lox" => "skip",
    }

    no_java_resolution = {
      "test/closure/assign_to_shadowed_later.lox" => "skip",
      "test/function/local_mutual_recursion.lox" => "skip",
      "test/variable/collide_with_parameter.lox" => "skip",
      "test/variable/duplicate_local.lox" => "skip",
      "test/variable/duplicate_parameter.lox" => "skip",
      "test/variable/early_bound.lox" => "skip",

      # Broken because we haven"t fixed it yet by detecting the error.
      "test/return/at_top_level.lox" => "skip",
      "test/variable/use_local_in_initializer.lox" => "skip",
    }

    no_c_control_flow = {
      "test/block/empty.lox" => "skip",
      "test/for" => "skip",
      "test/if" => "skip",
      "test/limit/loop_too_large.lox" => "skip",
      "test/logical_operator" => "skip",
      "test/variable/unreached_undefined.lox" => "skip",
      "test/while" => "skip",
    }

    no_c_functions = {
      "test/call" => "skip",
      "test/closure" => "skip",
      "test/for/closure_in_body.lox" => "skip",
      "test/for/return_closure.lox" => "skip",
      "test/for/return_inside.lox" => "skip",
      "test/for/syntax.lox" => "skip",
      "test/function" => "skip",
      "test/limit/no_reuse_constants.lox" => "skip",
      "test/limit/stack_overflow.lox" => "skip",
      "test/limit/too_many_constants.lox" => "skip",
      "test/limit/too_many_locals.lox" => "skip",
      "test/limit/too_many_upvalues.lox" => "skip",
      "test/regression/40.lox" => "skip",
      "test/return" => "skip",
      "test/unexpected_character.lox" => "skip",
      "test/variable/collide_with_parameter.lox" => "skip",
      "test/variable/duplicate_parameter.lox" => "skip",
      "test/variable/early_bound.lox" => "skip",
      "test/while/closure_in_body.lox" => "skip",
      "test/while/return_closure.lox" => "skip",
      "test/while/return_inside.lox" => "skip",
    }

    no_c_classes = {
      "test/assignment/to_this.lox" => "skip",
      "test/call/object.lox" => "skip",
      "test/class" => "skip",
      "test/closure/close_over_method_parameter.lox" => "skip",
      "test/constructor" => "skip",
      "test/field" => "skip",
      "test/inheritance" => "skip",
      "test/method" => "skip",
      "test/number/decimal_point_at_eof.lox" => "skip",
      "test/number/trailing_dot.lox" => "skip",
      "test/operator/equals_class.lox" => "skip",
      "test/operator/equals_method.lox" => "skip",
      "test/operator/not.lox" => "skip",
      "test/operator/not_class.lox" => "skip",
      "test/regression/394.lox" => "skip",
      "test/return/in_method.lox" => "skip",
      "test/super" => "skip",
      "test/this" => "skip",
      "test/variable/local_from_method.lox" => "skip",
    }

    no_c_inheritance = {
      "test/class/local_inherit_other.lox" => "skip",
      "test/class/local_inherit_self.lox" => "skip",
      "test/class/inherit_self.lox" => "skip",
      "test/class/inherited_method.lox" => "skip",
      "test/inheritance" => "skip",
      "test/regression/394.lox" => "skip",
      "test/super" => "skip",
    }

    java.call("jlox", { "test" => "pass" }.merge(early_chapters, java_NaN_equality, no_java_limits))
    java.call("chap04_scanning", { "test" => "skip", "test/scanning" => "pass" })
    java.call("chap06_parsing", { "test" => "skip", "test/expressions/parse.lox" => "pass" })
    java.call("chap07_evaluating", { "test" => "skip", "test/expressions/evaluate.lox" => "pass" })
    java.call("chap08_statements", { "test" => "pass" }.merge(
      early_chapters,
      java_NaN_equality,
      no_java_limits,
      no_java_functions,
      no_java_resolution,
      no_java_classes,
      {
        # No control flow.
        "test/block/empty.lox" => "skip",
        "test/for" => "skip",
        "test/if" => "skip",
        "test/logical_operator" => "skip",
        "test/while" => "skip",
        "test/variable/unreached_undefined.lox" => "skip",
      }
    ))
    java.call("chap09_control", { "test" => "pass" }.merge(early_chapters, java_NaN_equality, no_java_limits, no_java_functions, no_java_resolution, no_java_classes))
    java.call("chap10_functions", { "test" => "pass" }.merge(early_chapters, java_NaN_equality, no_java_limits, no_java_resolution, no_java_classes))
    java.call("chap11_resolving", { "test" => "pass" }.merge(early_chapters, java_NaN_equality, no_java_limits, no_java_classes))
    java.call("chap12_classes", { "test" => "pass" }.merge(early_chapters, no_java_limits, java_NaN_equality, {
      # No inheritance.
      "test/class/local_inherit_other.lox" => "skip",
      "test/class/local_inherit_self.lox" => "skip",
      "test/class/inherit_self.lox" => "skip",
      "test/class/inherited_method.lox" => "skip",
      "test/inheritance" => "skip",
      "test/regression/394.lox" => "skip",
      "test/super" => "skip",
    }))
    java.call("chap13_inheritance", { "test" => "pass" }.merge(early_chapters, java_NaN_equality, no_java_limits))

    c.call("clox", { "test" => "pass" }.merge(early_chapters))
    c.call("chap17_compiling", { "test" => "skip",  "test/expressions/evaluate.lox" => "pass" })
    c.call("chap18_types", { "test" => "skip", "test/expressions/evaluate.lox" => "pass" })
    c.call("chap19_strings", { "test" => "skip", "test/expressions/evaluate.lox" => "pass" })
    c.call("chap20_hash", { "test" => "skip", "test/expressions/evaluate.lox" => "pass" })
    c.call("chap21_global", { "test" => "pass" }.merge(
      early_chapters,
      no_c_control_flow,
      no_c_functions,
      no_c_classes,

      # No blocks.
      "test/assignment/local.lox" => "skip",
      "test/variable/in_middle_of_block.lox" => "skip",
      "test/variable/in_nested_block.lox" => "skip",
      "test/variable/scope_reuse_in_different_blocks.lox" => "skip",
      "test/variable/shadow_and_local.lox" => "skip",
      "test/variable/undefined_local.lox" => "skip",

      # No local variables.
      "test/block/scope.lox" => "skip",
      "test/variable/duplicate_local.lox" => "skip",
      "test/variable/shadow_global.lox" => "skip",
      "test/variable/shadow_local.lox" => "skip",
      "test/variable/use_local_in_initializer.lox" => "skip",
    ))
    c.call("chap22_local", { "test" => "pass" }.merge(early_chapters, no_c_control_flow, no_c_functions, no_c_classes))
    c.call("chap23_jumping", { "test" => "pass" }.merge(early_chapters, no_c_functions, no_c_classes))
    c.call("chap24_calls", { "test" => "pass" }.merge(early_chapters, no_c_classes, {
      # No closures.
      "test/closure" => "skip",
      "test/for/closure_in_body.lox" => "skip",
      "test/for/return_closure.lox" => "skip",
      "test/function/local_recursion.lox" => "skip",
      "test/limit/too_many_upvalues.lox" => "skip",
      "test/regression/40.lox" => "skip",
      "test/while/closure_in_body.lox" => "skip",
      "test/while/return_closure.lox" => "skip",
    }))
    c.call("chap25_closures", { "test" => "pass" }.merge(early_chapters, no_c_classes))
    c.call("chap26_garbage", { "test" => "pass" }.merge(early_chapters, no_c_classes))
    c.call("chap27_classes", { "test" => "pass" }.merge(early_chapters, no_c_inheritance, {
      # No methods.
      "test/assignment/to_this.lox" => "skip",
      "test/class/local_reference_self.lox" => "skip",
      "test/class/reference_self.lox" => "skip",
      "test/closure/close_over_method_parameter.lox" => "skip",
      "test/constructor" => "skip",
      "test/field/get_and_set_method.lox" => "skip",
      "test/field/method.lox" => "skip",
      "test/field/method_binds_this.lox" => "skip",
      "test/method" => "skip",
      "test/operator/equals_class.lox" => "skip",
      "test/operator/equals_method.lox" => "skip",
      "test/return/in_method.lox" => "skip",
      "test/this" => "skip",
      "test/variable/local_from_method.lox" => "skip",
    }))
    c.call("chap28_methods", { "test" => "pass" }.merge(early_chapters, no_c_inheritance))
    c.call("chap29_superclasses", { "test" => "pass" }.merge(early_chapters))
    c.call("chap30_optimization", { "test" => "pass" }.merge(early_chapters))
  end
end

main
