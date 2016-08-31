# Copyright (c) 2011 Artem Kuzko
# Copyright (c) 2013 Zach Belzer
# Copyright (c) 2013 Arthur Shagall
# Released under the MIT license.  See LICENSE for details.

# Used to patch ActiveRecord reflections.
module PowerEnum::Reflection
  extend ActiveSupport::Concern

  # Class-level extensions injected into ActiveRecord
  module ClassMethods
    def self.extended(base) # :nodoc:
      class << base
        alias_method_chain :reflect_on_all_associations, :enumeration
        alias_method_chain :reflect_on_association, :enumeration
      end
    end

    # All {PowerEnum::Reflection::EnumerationReflection} reflections
    def reflect_on_all_enumerated
      # Need to give it a full namespace to avoid getting Rails confused in development
      # mode where all objects are reloaded on every request.
      reflections.values.grep(PowerEnum::Reflection::EnumerationReflection)
    end

    # If the reflection of the given name is an EnumerationReflection, returns
    # the reflection, otherwise returns nil.
    # @return [PowerEnum::Reflection::EnumerationReflection]
    def reflect_on_enumerated( enumerated )
      key = if Rails.version =~ /^4\.2.*/ || Rails.version =~ /5.*/
              enumerated.to_s
            else
              enumerated.to_sym
            end
      reflections[key].is_a?(PowerEnum::Reflection::EnumerationReflection) ? reflections[key] : nil
    end

    # Extend associations with enumerations, preferring enumerations
    def reflect_on_all_associations_with_enumeration(macro = nil)
      reflect_on_all_enumerated + reflect_on_all_associations_without_enumeration(macro)
    end

    # Extend associations with enumerations, preferring enumerations
    def reflect_on_association_with_enumeration( associated )
      reflect_on_enumerated(associated) || reflect_on_association_without_enumeration(associated)
    end
  end

  # Reflection class for enum reflections.  See ActiveRecord::Reflection
  class EnumerationReflection < ActiveRecord::Reflection::MacroReflection
    attr_reader :counter_cache_column
    attr_accessor :parent_reflection

    # See ActiveRecord::Reflection::MacroReflection
    def initialize( name, options, active_record )
      if Rails.version =~ /^4\.2.*/ || Rails.version =~ /5.*/
        super name, nil, options, active_record
      else
        super :has_enumerated, name, nil, options, active_record
      end
    end

    if Rails.version =~ /^4\.2.*/ || Rails.version =~ /5.*/
      def macro
        :has_enumerated
      end

      def check_preloadable!
        return unless scope
        if scope.arity > 0
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
The association scope '#{name}' is instance dependent (the scope
block takes an argument). Preloading happens before the individual
instances are created. This means that there is no instance being
passed to the association scope. This will most likely result in
broken or incorrect behavior. Joining, Preloading and eager loading
of these associations is deprecated and will be removed in the future.
          MSG
        end
      end
      alias :check_eager_loadable! :check_preloadable!

      def active_record_primary_key
        @active_record_primary_key ||= options[:primary_key] || active_record.primary_key
      end

      def klass
        @klass ||= active_record.send(:compute_type, class_name)
      end

      EnumJoinKeys = Struct.new(:key, :foreign_key)

      def join_keys(_)
        EnumJoinKeys.new(active_record_primary_key, foreign_key)
      end
    end

    # Returns the class name of the enum
    def class_name
      @class_name ||= (@options[:class_name] || @name).to_s.camelize
    end

    # Returns the foreign key on the association owner's table.
    def foreign_key
      @foreign_key ||= (@options[:foreign_key] || "#{@name}_id").to_s
    end

    # Returns the name of the enum table
    def table_name
      @table_name ||= self.class.const_get(class_name).table_name
    end

    # Returns the primary key of the active record model that owns the has_enumerated
    # association.
    def association_primary_key(klass = nil)
      active_record.primary_key
    end

    # Does nothing.
    def check_validity!; end

    # Returns nil
    def source_reflection;
      nil
    end

    # Returns nil
    def type
      nil
    end

    # Always returns false. Necessary for stuff like Booking.where(:status => BookingStatus[:confirmed])
    def polymorphic?
      false
    end

    # In this case, returns [[]]
    def conditions
      [[]]
    end

    # Returns :belongs_to.  Kind of hackish, but otherwise AREL joins logic
    # gets confused.
    def source_macro
      :belongs_to
    end

    # Returns an array of this instance as the only member.
    def chain
      [self]
    end

    # Normally defined on AR::AssociationReflection::MacroReflection.
    # Realistically, this is a belongs-to relationship.
    def belongs_to?
      true
    end

    # An array of arrays of scopes. Each item in the outside array corresponds
    # to a reflection in the #chain.
    def scope_chain
      scope ? [[scope]] : [[]]
    end

  end
end
