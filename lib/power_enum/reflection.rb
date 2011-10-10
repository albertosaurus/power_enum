module PowerEnum::Reflection
  extend ActiveSupport::Concern

  module ClassMethods
    def reflect_on_all_enumerated
      reflections.values.grep(EnumerationReflection)
    end

    def reflect_on_enumerated enumerated
      reflections[enumerated.to_sym].is_a?(EnumerationReflection) ? reflections[enumerated.to_sym] : nil
    end
  end

  class EnumerationReflection < ActiveRecord::Reflection::MacroReflection
    def initialize name, options, active_record
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
