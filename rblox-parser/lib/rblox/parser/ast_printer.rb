module Rblox
  module Parser
    class AstPrinter
      def print(expr)
        expr.accept(self)
      end

      def visit_print_stmt(stmt)
        "print #{print(stmt.expression)};"
      end

      def visit_expression_stmt(stmt)
        "#{print(stmt.expression)};"
      end

      def visit_binary_expr(expr)
        parenthesize(expr.operator.lexeme, expr.left, expr.right)
      end

      def visit_grouping_expr(expr)
        parenthesize("group", expr.expression)
      end

      def visit_literal_expr(expr)
        return "nil" if expr.value.nil?
        return "\"#{expr.value}\"" if expr.value.is_a?(String)

        expr.value.to_s
      end

      def visit_unary_expr(expr)
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
