module Rblox
  module Parser
    module Expr
      def self.define_expr(name, *parameters)
        const_set(name, Struct.new(*parameters) do
          def accept(visitor)
            visitor.public_send("visit_#{self.class.name.split("::").last.downcase}_expr", self)
          end
        end)
      end

      define_expr(:Assign, :name, :value)
      define_expr(:Binary, :left, :operator, :right)
      define_expr(:Call, :callee, :paren, :arguments)
      define_expr(:Get, :object, :name)
      define_expr(:Grouping, :expression)
      define_expr(:Literal, :value)
      define_expr(:Logical, :left, :operator, :right)
      define_expr(:Set, :object, :name, :value)
      define_expr(:Super, :keyword, :method)
      define_expr(:This, :keyword)
      define_expr(:Unary, :operator, :right)
      define_expr(:Variable, :name)
    end
  end
end
