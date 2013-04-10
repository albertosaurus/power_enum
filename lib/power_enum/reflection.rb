# Copyright (c) 2011 Artem Kuzko
# Copyright (c) 2013 Zach Belzer
# Copyright (c) 2013 Arthur Shagall
# Released under the MIT license.  See LICENSE for details.

# Used to patch ActiveRecord reflections.
module PowerEnum::Reflection
  extend ActiveSupport::Concern

  module ClassMethods
    def self.extended(base)
      class << base
        alias_method_chain :reflect_on_all_associations, :enumeration
        alias_method_chain :reflect_on_association, :enumeration
      end
    end

    def reflect_on_all_enumerated
      # Need to give it a full namespace to avoid getting Rails confused in development
      # mode where all objects are reloaded on every request.
      reflections.values.grep(PowerEnum::Reflection::EnumerationReflection)
    end

    def reflect_on_enumerated( enumerated )
      reflections[enumerated.to_sym].is_a?(PowerEnum::Reflection::EnumerationReflection) ? reflections[enumerated.to_sym] : nil
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

    # See ActiveRecore::Reflection::MacroReflection
    def initialize( name, options, active_record )
      super :has_enumerated, name, options, active_record
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
    def association_primary_key
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
    # Absence of this method on EnumerationReflection causes ransack_ui to barf.
    def belongs_to?
      false
    end

  end
end
