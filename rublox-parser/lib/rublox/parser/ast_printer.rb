module Rublox
  module Parser
    class AstPrinter
      def print(expr)
        return expr.accept(self)
      end

      def visit_print(stmt)
        "print #{print(stmt.expression)};"
      end

      def visit_expression(stmt)
        "#{print(stmt.expression)};"
      end

      def visit_binary(expr)
        parenthesize(expr.operator.lexeme, expr.left, expr.right)
      end

      def visit_grouping(expr)
        parenthesize("group", expr.expression)
      end

      def visit_literal(expr)
        return "nil" if expr.value.nil?
        return "\"#{expr.value}\"" if expr.value.is_a?(String)

        expr.value.to_s
      end

      def visit_unary(expr)
        parenthesize(expr.operator.lexeme, expr.right)
      end

      private

      def parenthesize(name, *exprs)
        printed_exprs = exprs.map { |expr| expr.accept(self) }
        "(#{name} #{printed_exprs.join(" ")})"
      end
    end
  end
end
