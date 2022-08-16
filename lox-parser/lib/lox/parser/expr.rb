module Lox
  module Parser
    module Expr
      def self.define_expr(name, *parameters)
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
