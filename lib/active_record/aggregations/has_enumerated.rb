# Copyright (c) 2005 Trevor Squires
# Released under the MIT License.  See the LICENSE file for more details.

module ActiveRecord
  module Aggregations # :nodoc:
    module HasEnumerated # :nodoc:
      def self.append_features(base)
        super      
        base.extend(MacroMethods)
      end

      module MacroMethods
        def enumerated_attributes
          @enumerated_attributes ||= []
        end

        def has_enumerated?(attribute)
          return false unless attribute
          enumerated_attributes.include? attribute.to_s
        end

        def has_enumerated(part_id, options = {})
          options.assert_valid_keys(:class_name, :foreign_key, :on_lookup_failure)

          reflection = PowerEnum::Reflection::EnumerationReflection.new(part_id, options, self)
          self.reflections.merge! part_id => reflection

          name        = part_id.to_s
          class_name  = reflection.class_name
          foreign_key = reflection.foreign_key
          failure     = options[:on_lookup_failure]

          module_eval <<-end_eval
            def #{name}
              rval = #{class_name}.lookup_id(self.#{foreign_key})
              if rval.nil? && #{!failure.nil?}
                return self.send(#{failure.inspect}, :read, #{name.inspect}, #{foreign_key.inspect}, #{class_name.inspect}, self.#{foreign_key})
              end
              return rval
            end         

            def #{name}=(arg)
              arg = nil if arg.is_a?(String) && arg.empty?
              case arg
              when #{class_name}
                val = #{class_name}.lookup_id(arg.id)
              when String
                val = #{class_name}.lookup_name(arg)
              when Symbol
                val = #{class_name}.lookup_name(arg.id2name)
              when Fixnum
                val = #{class_name}.lookup_id(arg)
              when nil
                self.#{foreign_key} = nil
                return nil
              else     
                raise TypeError, "#{self.name}: #{name}= argument must be a #{class_name}, String, Symbol or Fixnum but got a: \#{arg.class.name}"            
              end

              if val.nil? 
                if #{failure.nil?}
                  raise ArgumentError, "#{self.name}: #{name}= can't assign a #{class_name} for a value of (\#{arg.inspect})"
                end
                self.send(#{failure.inspect}, :write, #{name.inspect}, #{foreign_key.inspect}, #{class_name.inspect}, arg)
              else
                self.#{foreign_key} = val.id
              end
            end
          end_eval

          enumerated_attributes << name

        end
      end
    end
  end
end
