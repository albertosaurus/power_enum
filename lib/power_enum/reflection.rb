# Copyright (c) 2011 Artem Kuzko
# Released under the MIT license.  See LICENSE for details.

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
    def reflect_on_all_associations_with_enumeration
      reflect_on_all_enumerated + reflect_on_all_associations_without_enumeration
    end

    # Extend associations with enumerations, preferring enumerations
    def reflect_on_association_with_enumeration( associated )
      reflect_on_enumerated(associated) || reflect_on_association_without_enumeration(associated)
    end
  end

  class EnumerationReflection < ActiveRecord::Reflection::MacroReflection
    def initialize( name, options, active_record )
      super :has_enumerated, name, options, active_record
    end
    
    def class_name
      @class_name ||= (@options[:class_name] || @name).to_s.camelize
    end
    
    def foreign_key
      @foreign_key ||= (@options[:foreign_key] || "#{@name}_id").to_s
    end
  end
end
