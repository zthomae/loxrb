module Rblox
  module TreeWalker
    class Interpreter
      attr_reader :globals

      def initialize(error_handler)
        @error_handler = error_handler
        @globals = Environment.new
        @globals.define(
          "clock",
          NativeFunction.new(0) do |interpreter, arguments|
            Time.now.strftime("%s%L").to_f / 1000.0
          end
        )
        @environment = @globals
        @locals = {}
      end

      def interpret(statements)
        statements.each do |statement|
          execute(statement)
        end
      rescue LanguageRuntimeError => e
        @error_handler.runtime_error(e)
      end

      def visit_block_stmt(stmt)
        execute_block(stmt.statements, Environment.new(@environment))
      end

      def visit_class_stmt(stmt)
        if !stmt.superclass.nil?
          superclass = evaluate(stmt.superclass)
          if !superclass.is_a?(UserDefinedClass)
            raise LanguageRuntimeError.new(stmt.superclass.name, "Superclass must be a class.")
          end
        end

        @environment.define(stmt.name.lexeme, nil)

        if !stmt.superclass.nil?
          @environment = Environment.new(@environment)
          @environment.define("super", superclass)
        end

        methods = {}
        stmt.methods.each do |method|
          function = UserDefinedFunction.new(method, @environment, is_initializer: method.name.lexeme == "init")
          methods[method.name.lexeme] = function
        end

        klass = UserDefinedClass.new(stmt.name.lexeme, superclass, methods)

        if !superclass.nil?
          @environment = @environment.enclosing
        end

        @environment.assign(stmt.name, klass)
      end

      def visit_expression_stmt(stmt)
        evaluate(stmt.expression)
      end

      def visit_function_stmt(stmt)
        function = UserDefinedFunction.new(stmt, @environment, is_initializer: false)
        @environment.define(stmt.name.lexeme, function)
      end

      def visit_if_stmt(stmt)
        if is_truthy?(evaluate(stmt.condition))
          execute(stmt.then_branch)
        elsif !stmt.else_branch.nil?
          execute(stmt.else_branch)
        end
      end

      def visit_print_stmt(stmt)
        value = evaluate(stmt.expression)
        puts stringify(value)
      end

      def visit_return_stmt(stmt)
        if !stmt.value.nil?
          value = evaluate(stmt.value)
        end

        raise RuntimeReturn.new(value)
      end

      def visit_var_stmt(stmt)
        if !stmt.initializer.nil?
          value = evaluate(stmt.initializer)
        end

        @environment.define(stmt.name.lexeme, value)
      end

      def visit_while_stmt(stmt)
        while is_truthy?(evaluate(stmt.condition))
          execute(stmt.body)
        end
      end

      def visit_literal_expr(expr)
        expr.value
      end

      def visit_logical_expr(expr)
        left = evaluate(expr.left)

        if expr.operator.type == Rblox::Parser::TokenType::OR
          return left if is_truthy?(left)
        elsif !is_truthy?(left)
          return left
        end

        evaluate(expr.right)
      end

      def visit_grouping_expr(expr)
        evaluate(expr.expression)
      end

      def visit_unary_expr(expr)
        right = evaluate(expr.right)

        case expr.operator.type
        when Rblox::Parser::TokenType::BANG
          !is_truthy?(right)
        when Rblox::Parser::TokenType::MINUS
          check_number_operand(expr.operator, right)
          -right
        end
      end

      def visit_binary_expr(expr)
        left = evaluate(expr.left)
        right = evaluate(expr.right)

        case expr.operator.type
        when Rblox::Parser::TokenType::GREATER
          check_number_operands(expr.operator, left, right)
          left > right
        when Rblox::Parser::TokenType::GREATER_EQUAL
          check_number_operands(expr.operator, left, right)
          left >= right
        when Rblox::Parser::TokenType::LESS
          check_number_operands(expr.operator, left, right)
          left < right
        when Rblox::Parser::TokenType::LESS_EQUAL
          check_number_operands(expr.operator, left, right)
          left <= right
        when Rblox::Parser::TokenType::BANG_EQUAL
          !is_equal?(left, right)
        when Rblox::Parser::TokenType::EQUAL_EQUAL
          is_equal?(left, right)
        when Rblox::Parser::TokenType::MINUS
          check_number_operands(expr.operator, left, right)
          left - right
        when Rblox::Parser::TokenType::PLUS
          if (left.is_a?(Float) && right.is_a?(Float)) || (left.is_a?(String) && right.is_a?(String))
            return left + right
          end

          raise LanguageRuntimeError.new(expr.operator, "Operands must be two numbers or two strings.")
        when Rblox::Parser::TokenType::SLASH
          check_number_operands(expr.operator, left, right)
          left / right
        when Rblox::Parser::TokenType::STAR
          check_number_operands(expr.operator, left, right)
          left * right
        end
      end

      def visit_call_expr(expr)
        callee = evaluate(expr.callee)

        arguments = expr.arguments.map(&method(:evaluate))

        if !callee.respond_to?(:arity) || !callee.respond_to?(:call)
          raise LanguageRuntimeError.new(expr.paren, "Can only call functions and classes.")
        end

        if arguments.count != callee.arity
          raise LanguageRuntimeError.new(expr.paren, "Expected #{callee.arity} arguments but got #{arguments.count}.")
        end

        callee.call(self, arguments)
      end

      def visit_get_expr(expr)
        object = evaluate(expr.object)
        if object.is_a?(UserDefinedClassInstance)
          return object.get(expr.name)
        end

        raise LanguageRuntimeError.new(expr.name, "Only instances have properties.")
      end

      def visit_set_expr(expr)
        object = evaluate(expr.object)

        if !object.is_a?(UserDefinedClassInstance)
          raise LanguageRuntimeError.new(expr.name, "Only instances have fields.")
        end

        value = evaluate(expr.value)
        object.set(expr.name, value)
        value
      end

      def visit_super_expr(expr)
        distance = get_local(expr)
        superclass = @environment.get_at(distance, "super")
        object = @environment.get_at(distance - 1, "this")
        method = superclass.find_method(expr.method.lexeme)
        if method.nil?
          raise LanguageRuntimeError.new(expr.method, "Undefined property '#{expr.method.lexeme}'.")
        end
        method.bind(object)
      end

      def visit_this_expr(expr)
        lookup_variable(expr.keyword, expr)
      end

      def visit_variable_expr(expr)
        lookup_variable(expr.name, expr)
      end

      def visit_assign_expr(expr)
        value = evaluate(expr.value)

        distance = get_local(expr)
        if !distance.nil?
          @environment.assign_at(distance, expr.name, value)
        else
          @globals.assign(expr.name, value)
        end

        value
      end

      def execute_block(statements, environment)
        previous = @environment

        begin
          @environment = environment
          statements.each { |statement| execute(statement) }
        ensure
          @environment = previous
        end
      end

      def resolve(expr, depth)
        set_local(expr, depth)
      end

      private

      def execute(stmt)
        stmt.accept(self)
      end

      def evaluate(expr)
        expr.accept(self)
      end

      def lookup_variable(name, expr)
        distance = get_local(expr)
        if !distance.nil?
          @environment.get_at(distance, name.lexeme)
        else
          @globals.get(name)
        end
      end

      def is_truthy?(object)
        !object.nil? && object != false
      end

      def is_equal?(a, b)
        # Mostly trivial, but unlike the original, (0.0 / 0.0) == (0.0 / 0.0) actually follows IEEE 754
        a == b
      end

      def check_number_operand(operator, operand)
        return if operand.is_a?(Float)

        raise LanguageRuntimeError.new(operator, "Operand must be a number.")
      end

      def check_number_operands(operator, left, right)
        return if left.is_a?(Float) && right.is_a?(Float)

        raise LanguageRuntimeError.new(operator, "Operands must be numbers.")
      end

      def stringify(object)
        return "nil" if object.nil?

        if object.is_a?(Float)
          text = object.to_s
          if text.end_with?(".0")
            text = text[0...text.length - 2]
          end
          return text
        end

        object.to_s
      end

      def get_local(expr)
        @locals[expr.object_id]
      end

      def set_local(expr, depth)
        @locals[expr.object_id] = depth
      end
    end
  end
end
