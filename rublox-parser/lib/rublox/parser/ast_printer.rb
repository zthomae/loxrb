module Rublox
  module Parser
    class AstPrinter
      def print(expr)
        return expr.accept(self)
      end

      def visit_binary(expr)
        parenthesize(expr.operator.lexeme, expr.left, expr.right)
      end

      def visit_grouping(expr)
        parenthesize("group", expr.expression)
      end

      def visit_literal(expr)
        return "nil" if expr.value.nil?

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
