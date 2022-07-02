# The book used code generation for this. I don't think I need to bother -- Struct makes this easy enough.
module Rublox
  module Parser
    module Expr
      Assign = Struct.new(:name, :value) do
        def accept(visitor)
          visitor.visit_assign_expr(self)
        end
      end

      Binary = Struct.new(:left, :operator, :right) do
        def accept(visitor)
          visitor.visit_binary_expr(self)
        end
      end

      Call = Struct.new(:callee, :paren, :arguments) do
        def accept(visitor)
          visitor.visit_call_expr(self)
        end
      end

      Get = Struct.new(:object, :name) do
        def accept(visitor)
          visitor.visit_get_expr(self)
        end
      end

      Grouping = Struct.new(:expression) do
        def accept(visitor)
          visitor.visit_grouping_expr(self)
        end
      end

      Literal = Struct.new(:value) do
        def accept(visitor)
          visitor.visit_literal_expr(self)
        end
      end

      Logical = Struct.new(:left, :operator, :right) do
        def accept(visitor)
          visitor.visit_logical_expr(self)
        end
      end

      Set = Struct.new(:object, :name, :value) do
        def accept(visitor)
          visitor.visit_set_expr(self)
        end
      end

      This = Struct.new(:keyword) do
        def accept(visitor)
          visitor.visit_this_expr(self)
        end
      end

      Unary = Struct.new(:operator, :right) do
        def accept(visitor)
          visitor.visit_unary_expr(self)
        end
      end

      Variable = Struct.new(:name) do
        def accept(visitor)
          visitor.visit_variable_expr(self)
        end
      end
    end
  end
end
