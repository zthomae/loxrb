module Rblox
  module Test
    class Collection
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
          @all_suites[name] = Suite.new(name, "java", "exe/rblox-treewalker", [], tests)
          @java_suites.append(name)
        end

        early_chapters = {
          "test/scanning" => "skip",
          "test/expressions" => "skip"
        }

        java_nan_equality = {
          "test/number/nan_equality.lox" => "skip"
        }

        no_java_limits = {
          "test/limit/loop_too_large.lox" => "skip",
          "test/limit/no_reuse_constants.lox" => "skip",
          "test/limit/too_many_constants.lox" => "skip",
          "test/limit/too_many_locals.lox" => "skip",
          "test/limit/too_many_upvalues.lox" => "skip",

          # Rely on JVM for stack overflow checking.
          "test/limit/stack_overflow.lox" => "skip"
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
          "test/variable/local_from_method.lox" => "skip"
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
          "test/while/return_inside.lox" => "skip"
        }

        no_java_resolution = {
          "test/closure/assign_to_shadowed_later.lox" => "skip",
          "test/function/local_mutual_recursion.lox" => "skip",
          "test/variable/collide_with_parameter.lox" => "skip",
          "test/variable/duplicate_local.lox" => "skip",
          "test/variable/duplicate_parameter.lox" => "skip",
          "test/variable/early_bound.lox" => "skip",

          # Broken because we haven't fixed it yet by detecting the error.
          "test/return/at_top_level.lox" => "skip",
          "test/variable/use_local_in_initializer.lox" => "skip"
        }

        no_c_control_flow = {
          "test/block/empty.lox" => "skip",
          "test/for" => "skip",
          "test/if" => "skip",
          "test/limit/loop_too_large.lox" => "skip",
          "test/logical_operator" => "skip",
          "test/variable/unreached_undefined.lox" => "skip",
          "test/while" => "skip"
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
          "test/while/return_inside.lox" => "skip"
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
          "test/variable/local_from_method.lox" => "skip"
        }

        no_c_inheritance = {
          "test/class/local_inherit_other.lox" => "skip",
          "test/class/local_inherit_self.lox" => "skip",
          "test/class/inherit_self.lox" => "skip",
          "test/class/inherited_method.lox" => "skip",
          "test/inheritance" => "skip",
          "test/regression/394.lox" => "skip",
          "test/super" => "skip"
        }

        java.call("jlox", {"test" => "pass"}.merge(early_chapters, java_nan_equality, no_java_limits))
        java.call("chap04", {"test" => "skip", "test/scanning" => "pass"})
        java.call("chap06", {"test" => "skip", "test/expressions/parse.lox" => "pass"})
        java.call("chap07", {"test" => "skip", "test/expressions/evaluate.lox" => "pass"})
        java.call("chap08", {"test" => "pass"}.merge(
          early_chapters,
          java_nan_equality,
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
            "test/variable/unreached_undefined.lox" => "skip"
          }
        ))
        java.call("chap09", {"test" => "pass"}.merge(early_chapters, java_nan_equality, no_java_limits, no_java_functions, no_java_resolution, no_java_classes))
        java.call("chap10", {"test" => "pass"}.merge(early_chapters, java_nan_equality, no_java_limits, no_java_resolution, no_java_classes))
        java.call("chap11", {"test" => "pass"}.merge(early_chapters, java_nan_equality, no_java_limits, no_java_classes))
        java.call("chap12", {"test" => "pass"}.merge(early_chapters, no_java_limits, java_nan_equality, {
          # No inheritance.
          "test/class/local_inherit_other.lox" => "skip",
          "test/class/local_inherit_self.lox" => "skip",
          "test/class/inherit_self.lox" => "skip",
          "test/class/inherited_method.lox" => "skip",
          "test/inheritance" => "skip",
          "test/regression/394.lox" => "skip",
          "test/super" => "skip"
        }))
        java.call("chap13", {"test" => "pass"}.merge(early_chapters, java_nan_equality, no_java_limits))

        c_hacks = {
          "test/limit/loop_too_large.lox" => "skip",
        }
        c.call("clox", {"test" => "pass"}.merge(early_chapters))
        c.call("chap17", {"test" => "skip", "test/expressions/evaluate.lox" => "pass"})
        c.call("chap18", {"test" => "skip", "test/expressions/evaluate.lox" => "pass"})
        c.call("chap19", {"test" => "skip", "test/expressions/evaluate.lox" => "pass"})
        c.call("chap20", {"test" => "skip", "test/expressions/evaluate.lox" => "pass"})
        c.call("chap21", {"test" => "pass"}.merge(
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
          "test/variable/use_local_in_initializer.lox" => "skip"
        ))
        c.call("chap22", {"test" => "pass"}.merge(early_chapters, no_c_control_flow, no_c_functions, no_c_classes))
        c.call("chap23", {"test" => "pass"}.merge(early_chapters, c_hacks, no_c_functions, no_c_classes))
        c.call("chap24", {"test" => "pass"}.merge(early_chapters, c_hacks, no_c_classes, {
          # No closures.
          "test/closure" => "skip",
          "test/for/closure_in_body.lox" => "skip",
          "test/for/return_closure.lox" => "skip",
          "test/function/local_recursion.lox" => "skip",
          "test/limit/too_many_upvalues.lox" => "skip",
          "test/regression/40.lox" => "skip",
          "test/while/closure_in_body.lox" => "skip",
          "test/while/return_closure.lox" => "skip"
        }))
        c.call("chap25", {"test" => "pass"}.merge(early_chapters, c_hacks, no_c_classes))
        c.call("chap26", {"test" => "pass"}.merge(early_chapters, c_hacks, no_c_classes))
        c.call("chap27", {"test" => "pass"}.merge(early_chapters, c_hacks, no_c_inheritance, {
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
          "test/variable/local_from_method.lox" => "skip"
        }))
        c.call("chap28", {"test" => "pass"}.merge(early_chapters, c_hacks, no_c_inheritance))
        c.call("chap29", {"test" => "pass"}.merge(early_chapters, c_hacks))
        c.call("chap30", {"test" => "pass"}.merge(early_chapters, c_hacks))
      end
    end
  end
end
