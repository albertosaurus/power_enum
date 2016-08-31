# Copyright (c) 2005 Trevor Squires
# Copyright (c) 2012 Arthur Shagall
# Released under the MIT License.  See the LICENSE file for more details.

# Implementation of has_enumerated
module PowerEnum::HasEnumerated

  extend ActiveSupport::Concern

  # Class-level behavior injected into ActiveRecord to support has_enumerated
  module ClassMethods

    # Returns a list of all the attributes on the ActiveRecord model which are enumerated.
    def enumerated_attributes
      @enumerated_attributes ||= []
    end

    # Returns +true+ if +attribute+ is an enumerated attribute, +false+ otherwise.
    def has_enumerated?(attribute)
      return false if attribute.nil?
      enumerated_attributes.include? attribute.to_s
    end

    # Defines an enumerated attribute with the given attribute_name on the model.  Also accepts a hash of options as an
    # optional second argument.
    #
    # === Supported options
    # [:class_name]
    #   Name of the enum class.  By default it is the camelized version of the has_enumerated attribute.
    # [:foreign_key]
    #   Explicitly set the foreign key column.  By default it's assumed to be your_enumerated_attribute_name_id.
    # [:on_lookup_failure]
    #   The :on_lookup_failure option in has_enumerated is there because you may want to create an error handler for
    #   situations where the argument passed to status=(arg) is invalid. By default, an invalid value will cause an
    #   ArgumentError to be raised.  Since this may not be optimal in your situation, you can do one of three
    #   things:
    #
    #   1) You can set it to 'validation_error'.  In this case, the invalid value will be cached and returned on
    #   subsequent lookups, but the model will fail validation.
    #   2) You can specify an instance method to be called in the case of a lookup failure. The method signature is
    #   as follows:
    #     <tt>your_lookup_handler(operation, attribute_name, name_foreign_key, acts_enumerated_class_name, lookup_value)</tt>
    #   The 'operation' arg will be either :read or :write.  In the case of :read you are expected to return
    #   something or raise an exception, while in the case of a :write you don't have to return anything.  Note that
    #   there's enough information in the method signature that you can specify one method to handle all lookup
    #   failures for all has_enumerated fields if you happen to have more than one defined in your model.
    #   'NOTE': A nil is always considered to be a valid value for status=(arg) since it's assumed you're trying to
    #    null out the foreign key. The :on_lookup_failure method will be bypassed.
    #   3) You can give it a lambda function.  In that case, the lambda needs to accept the ActiveRecord model as
    #   its first argument, with the rest of the arguments being identical to the signature of the lookup handler
    #   instance method.
    # [:permit_empty_name]
    #   Setting this to 'true' disables automatic conversion of empty strings to nil.  Default is 'false'.
    # [:default]
    #   Setting this option will generate an after_initialize callback to set a default value on the attribute
    #   unless a non-nil one already exists.
    # [:create_scope]
    #   Setting this option to 'false' will disable automatically creating 'with_enum_attribute' and
    #   'exclude_enum_attribute' scope.
    #
    # === Example
    #  class Booking < ActiveRecord::Base
    #    has_enumerated  :status,
    #                    :class_name        => 'BookingStatus',
    #                    :foreign_key       => 'status_id',
    #                    :on_lookup_failure => :optional_instance_method,
    #                    :permit_empty_name => true,
    #                    :default           => :unconfirmed,
    #                    :create_cope       => false
    #  end
    #
    # === Example 2
    #
    #  class Booking < ActiveRecord::Base
    #    has_enumerated  :booking_status,
    #                    :class_name        => 'BookingStatus',
    #                    :foreign_key       => 'status_id',
    #                    :on_lookup_failure => lambda{ |record, op, attr, fk, cl_name, value|
    #                      # handle lookup failure
    #                    }
    #  end
    def has_enumerated(part_id, options = {})
      options.assert_valid_keys( :class_name,
                                 :foreign_key,
                                 :on_lookup_failure,
                                 :permit_empty_name,
                                 :default,
                                 :create_scope )

      # Add a reflection for the enumerated attribute.
      reflection       = create_ar_reflection(part_id, options)

      attribute_name   = part_id.to_s
      class_name       = reflection.class_name
      foreign_key      = reflection.foreign_key
      failure_opt      = options[:on_lookup_failure]
      allow_empty_name = options[:permit_empty_name]
      create_scope     = options[:create_scope]

      failure_handler = get_lookup_failure_handler(failure_opt)

      class_attribute "has_enumerated_#{attribute_name}_error_handler"
      self.send( "has_enumerated_#{attribute_name}_error_handler=", failure_handler )

      define_enum_accessor attribute_name, class_name, foreign_key, failure_handler
      define_enum_writer   attribute_name, class_name, foreign_key, failure_handler, allow_empty_name

      if failure_opt.to_s == 'validation_error'
        define_validation_error( attribute_name )
      end

      enumerated_attributes << attribute_name

      if options.has_key?(:default)
        define_default_enum_value( attribute_name, options[:default] )
      end

      unless create_scope == false
        define_enum_scope( attribute_name, class_name, foreign_key )
      end

    end # has_enumerated

    # Creates the ActiveRecord reflection
    def create_ar_reflection(part_id, options)
      reflection = PowerEnum::Reflection::EnumerationReflection.new(part_id, options, self)

      # ActiveRecord >= 4.1 handles this differently.
      if self.respond_to? :_reflections=
        if Rails.version =~ /^4\.2.*/ || Rails.version =~ /5.*/
          self._reflections = self._reflections.merge(part_id.to_s => reflection)
        else
          self._reflections = self._reflections.merge(part_id => reflection)
        end

      else
        self.reflections = self.reflections.merge(part_id => reflection)
      end
      reflection
    end
    private :create_ar_reflection

    # Defines the accessor method
    def define_enum_accessor(attribute_name, class_name, foreign_key, failure_handler) #:nodoc:
      module_eval( <<-end_eval, __FILE__, __LINE__ )
        def #{attribute_name}
          if @invalid_enum_values && @invalid_enum_values.has_key?(:#{attribute_name})
            return @invalid_enum_values[:#{attribute_name}]
          end
          rval = #{class_name}.lookup_id(self.#{foreign_key})
          if rval.nil? && #{!failure_handler.nil?}
            self.class.has_enumerated_#{attribute_name}_error_handler.call(self, :read, #{attribute_name.inspect}, #{foreign_key.inspect}, #{class_name.inspect}, self.#{foreign_key})
          else
            rval
          end
        end
      end_eval
    end
    private :define_enum_accessor

    # Defines the enum attribute writer method
    def define_enum_writer(attribute_name, class_name, foreign_key, failure_handler, allow_empty_name) #:nodoc:
      module_eval( <<-end_eval, __FILE__, __LINE__ )
        def #{attribute_name}=(arg)
          @invalid_enum_values ||= {}

          #{!allow_empty_name ? 'arg = nil if arg.blank?' : ''}
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
            @invalid_enum_values.delete :#{attribute_name}
            return nil
          else
            raise TypeError, "#{self.name}: #{attribute_name}= argument must be a #{class_name}, String, Symbol or Fixnum but got a: \#{arg.class.attribute_name}"
          end

          if val.nil?
            if #{failure_handler.nil?}
              raise ArgumentError, "#{self.name}: #{attribute_name}= can't assign a #{class_name} for a value of (\#{arg.inspect})"
            else
              @invalid_enum_values.delete :#{attribute_name}
              self.class.has_enumerated_#{attribute_name}_error_handler.call(self, :write, #{attribute_name.inspect}, #{foreign_key.inspect}, #{class_name.inspect}, arg)
            end
          else
            @invalid_enum_values.delete :#{attribute_name}
            self.#{foreign_key} = val.id
          end
        end

        alias_method :'#{attribute_name}_bak=', :'#{attribute_name}='
      end_eval
    end
    private :define_enum_writer

    # Defines the default value for the enumerated attribute.
    def define_default_enum_value(attribute_name, default) #:nodoc:
      set_default_method = "set_default_value_for_#{attribute_name}".to_sym

      after_initialize set_default_method

      define_method set_default_method do
        self.send("#{attribute_name}=", default) if self.send(attribute_name).nil?
      end
      private set_default_method
    end
    private :define_default_enum_value

    # Defines validation_error handling mechanism
    def define_validation_error(attribute_name) #:nodoc:
      module_eval(<<-end_eval, __FILE__, __LINE__)
          validate do
            if @invalid_enum_values && @invalid_enum_values.has_key?(:#{attribute_name})
              errors.add(:#{attribute_name}, "is invalid")
            end
          end

          def validation_error(operation, attribute_name, name_foreign_key, acts_enumerated_class_name, lookup_value)
            @invalid_enum_values ||= {}
            if operation == :write
              @invalid_enum_values[attribute_name.to_sym] = lookup_value
            else
              nil
            end
          end
          private :validation_error
      end_eval
    end
    private :define_validation_error

    # Defines the enum scopes on the model
    def define_enum_scope(attribute_name, class_name, foreign_key) #:nodoc:
      module_eval(<<-end_eval, __FILE__, __LINE__)
          scope :with_#{attribute_name}, lambda { |*args|
            ids = args.map{ |arg|
              n = #{class_name}[arg]
            }
            where(:#{foreign_key} => ids)
          }
          scope :exclude_#{attribute_name}, lambda {|*args|
            ids = #{class_name}.all - args.map{ |arg|
              n = #{class_name}[arg]
            }
            where(:#{foreign_key} => ids)
          }
      end_eval

      if (name_p = attribute_name.pluralize) != attribute_name
        module_eval(<<-end_eval, __FILE__, __LINE__)
            class << self
              alias_method :with_#{name_p}, :with_#{attribute_name}
              alias_method :exclude_#{name_p}, :exclude_#{attribute_name}
            end
        end_eval
      end
    end
    private :define_enum_scope

    # If the lookup failure handler is a method attribute_name, wraps it in a lambda.
    def get_lookup_failure_handler(failure_opt) # :nodoc:
      if failure_opt.nil?
        nil
      else
        case failure_opt
        when Proc
          failure_opt
        else
          lambda { |record, op, attr, fk, cl_name, value|
            record.send(failure_opt.to_s, op, attr, fk, cl_name, value)
          }
        end

      end
    end
    private :get_lookup_failure_handler

  end #module MacroMethods

end #module PowerEnum::HasEnumerated
