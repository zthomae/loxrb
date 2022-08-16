module Lox
  module Parser
    module Stmt
      def self.define_stmt(name, *parameters)
        const_set(name, Struct.new(*parameters) do
          def initialize(...)
            super
            line_numbers = members.flat_map do |member|
              value = public_send(member)
              if value.nil?
                []
              elsif value.is_a?(Array)
                value.flat_map do |v|
                  if v.nil?
                    []
                  else
                    v.bounding_lines
                  end
                end
              else
                value.bounding_lines
              end
            end.compact.uniq
            @starting_line = line_numbers.min
            @ending_line = line_numbers.max
          end

          def bounding_lines
            [@starting_line, @ending_line]
          end

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
