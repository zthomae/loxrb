module Rublox
  module Parser
    module Stmt
      Expression = Struct.new(:expression) do
        def accept(visitor)
          visitor.visit_expression(self)
        end
      end

      Print = Struct.new(:expression) do
        def accept(visitor)
          visitor.visit_print(self)
        end
      end
    end
  end
end
