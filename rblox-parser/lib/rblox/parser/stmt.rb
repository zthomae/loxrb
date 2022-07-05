module Rblox
  module Parser
    module Stmt
      def self.define_stmt(name, *parameters)
        const_set(name, Struct.new(*parameters) do
          def accept(visitor)
            visitor.public_send("visit_#{self.class.name.split("::").last.downcase}_stmt", self)
          end
        end)
      end

      define_stmt(:Block, :statements)
      define_stmt(:Class, :name, :superclass, :methods)
      define_stmt(:Expression, :expression)
      define_stmt(:Function, :name, :params, :body)
      define_stmt(:If, :condition, :then_branch, :else_branch)
      define_stmt(:Print, :expression)
      define_stmt(:Return, :keyword, :value)
      define_stmt(:Var, :name, :initializer)
      define_stmt(:While, :condition, :body)
    end
  end
end
