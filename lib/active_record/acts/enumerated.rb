# Copyright (c) 2005 Trevor Squires
# Released under the MIT License.  See the LICENSE file for more details.

module ActiveRecord
  module Acts 
    module Enumerated 
      def self.append_features(base)
        super        
        base.extend(MacroMethods)              
      end
      
      module MacroMethods          
        def acts_as_enumerated(options = {})
          valid_keys = [:conditions, :order, :on_lookup_failure, :name_column]
          options.assert_valid_keys(*valid_keys)
          
          valid_keys.each do |key|   
            write_inheritable_attribute("acts_enumerated_#{key.to_s}".to_sym, options[key]) if options.has_key? key
          end
          
          name_column = if options.has_key?(:name_column) then
                          options[:name_column].to_s.to_sym
                        else
                          :name
                        end
          write_inheritable_attribute(:acts_enumerated_name_column, name_column)
          
          unless self.is_a? ActiveRecord::Acts::Enumerated::ClassMethods
            extend ActiveRecord::Acts::Enumerated::ClassMethods
            
            class_eval do
              include ActiveRecord::Acts::Enumerated::InstanceMethods
              
              before_save :enumeration_model_update
              before_destroy :enumeration_model_update
              validates name_column, :presence => true, :uniqueness => true
              
              define_method :name do
                read_attribute( name_column )
              end
            end
          end
        end
      end
      
      module ClassMethods  
        attr_accessor :enumeration_model_updates_permitted

        # Returns all the enum values.  Caches results after the first time this method is run.
        def all
          return @all if @all
          conditions = read_inheritable_attribute(:acts_enumerated_conditions)
          order = read_inheritable_attribute(:acts_enumerated_order)
          @all = where(conditions).order(order).collect{|val| val.freeze}.freeze
        end

        # Returns all the active enum values.  See the 'active?' instance method.
        def active
          return @all_active if @all_active
          @all_active = all.select{ |enum| enum.active? }.freeze
        end

        # Returns all the inactive enum values.  See the 'inactive?' instance method.
        def inactive
          return @all_inactive if @all_inactive
          @all_inactive = all.select{ |enum| !enum.active? }.freeze
        end

        # Enum lookup by Symbol, String, or id.
        def [](arg)
          case arg
          when Symbol
            return_val = lookup_name(arg.id2name) and return return_val
          when String
            return_val = lookup_name(arg) and return return_val
          when Fixnum
            return_val = lookup_id(arg) and return return_val
          when nil
            nil
          else
            raise TypeError, "#{self.name}[]: argument should be a String, Symbol or Fixnum but got a: #{arg.class.name}"            
          end
          self.send((read_inheritable_attribute(:acts_enumerated_on_lookup_failure) || :enforce_none), arg)
        end

        # Enum lookup by id
        def lookup_id(arg)
          all_by_id[arg]
        end

        # Enum lookup by String
        def lookup_name(arg)
          all_by_name[arg]
        end

        # Returns true if the enum lookup by the given Symbol, String or id would have returned a value, false otherwise.
        def include?(arg)
          case arg
          when Symbol
            !lookup_name(arg.id2name).nil?
          when String
            !lookup_name(arg).nil?
          when Fixnum
            !lookup_id(arg).nil?
          when self
            possible_match = lookup_id(arg.id) 
            !possible_match.nil? && possible_match == arg
          else
            false
          end
        end

        # NOTE: purging the cache is sort of pointless because
        # of the per-process rails model.  
        # By default this blows up noisily just in case you try to be more 
        # clever than rails allows.  
        # For those times (like in Migrations) when you really do want to 
        # alter the records you can silence the carping by setting
        # enumeration_model_updates_permitted to true.
        def purge_enumerations_cache
          unless self.enumeration_model_updates_permitted
            raise "#{self.name}: cache purging disabled for your protection"
          end
          @all = @all_by_name = @all_by_id = @all_active = nil
        end

        # Returns the name of the column this enum uses as the basic underlying value.
        def name_column
          @name_column ||= read_inheritable_attribute( :acts_enumerated_name_column )
        end

        # ---Private methods---

        def all_by_id
          @all_by_id ||= all_by_attribute( :id )
        end
        private :all_by_id
        
        def all_by_name
          begin
            @all_by_name ||= all_by_attribute( :name )
          rescue NoMethodError => err
            if err.name == name_column
              raise TypeError, "#{self.name}: you need to define a '#{name_column}' column in the table '#{table_name}'"
            end
            raise
          end            
        end
        private :all_by_name

        def all_by_attribute(attr)
          all.inject({}) { |memo, item|
            memo[item.send(attr)] = item
            memo
          }.freeze
        end
        private :all_by_attribute
        
        def enforce_none(arg)
          nil
        end
        private :enforce_none

        def enforce_strict(arg)
          raise_record_not_found(arg)
        end
        private :enforce_strict

        def enforce_strict_literals(arg)
          raise_record_not_found(arg) if (Fixnum === arg) || (Symbol === arg)
          nil
        end
        private :enforce_strict_literals

        def enforce_strict_ids(arg)
          raise_record_not_found(arg) if Fixnum === arg
          nil
        end
        private :enforce_strict_ids

        def enforce_strict_symbols(arg)
          raise_record_not_found(arg) if Symbol === arg
          nil
        end
        private :enforce_strict_symbols

        def raise_record_not_found(arg)
          raise ActiveRecord::RecordNotFound, "Couldn't find a #{self.name} identified by (#{arg.inspect})"
        end
        private :raise_record_not_found
        
      end

      module InstanceMethods
        # Behavior depends on the type of +arg+.
        #
        # * If +arg+ is +nil+, returns +false+.
        # * If +arg+ is an instance of +Symbol+, +Fixnum+ or +String+, returns the result of +BookingStatus[:foo] == BookingStatus[arg]+.
        # * If +arg+ is an +Array+, returns +true+ if any member of the array returns +true+ for +===(arg)+, +false+ otherwise.
        # * In all other cases, delegates to +===(arg)+ of the superclass.
        #
        # Examples:
        #
        #     BookingStatus[:foo] === :foo #Returns true
        #     BookingStatus[:foo] === 'foo' #Returns true
        #     BookingStatus[:foo] === :bar #Returns false
        #     BookingStatus[:foo] === [:foo, :bar, :baz] #Returns true
        #     BookingStatus[:foo] === nil #Returns false
        #
        # You should note that defining an +:on_lookup_failure+ method that raises an exception will cause +===+ to also raise an exception for any lookup failure of +BookingStatus[arg]+.
        def ===(arg)
          case arg
          when nil
            false
          when Symbol, String, Fixnum
            return self == self.class[arg]
          when Array
            return self.in?(*arg)
          else
            super
          end
        end
        
        alias_method :like?, :===

        # Returns true if any element in the list returns true for ===(arg), false otherwise.
        def in?(*list)
          for item in list
            self === item and return true
          end
          false
        end

        # Returns the symbol representation of the name of the enum. BookingStatus[:foo].name_sym returns :foo.
        def name_sym
          self.name.to_sym
        end

        # By default enumeration #to_s should return stringified name of the enum. BookingStatus[:foo].to_s returns "foo"
        def to_s
          self.name.to_s
        end

        # Returns true if the instance is active, false otherwise.  If it has an attribute 'active',
        # returns the attribute cast to a boolean, otherwise returns true.  This method is used by the 'active'
        # class method to select active enums.
        def active?
          @_active_status ||= ( attributes.include?('active') ? !!self.active : true )
        end

        # Returns true if the instance is inactive, false otherwise.  Default implementations returns !active?
        # This method is used by the 'inactive' class method to select inactive enums.
        def inactive?
          !active?
        end

        # NOTE: updating the models that back an acts_as_enumerated is 
        # rather dangerous because of rails' per-process model.
        # The cached values could get out of synch between processes
        # and rather than completely disallow changes I make you jump 
        # through an extra hoop just in case you're defining your enumeration 
        # values in Migrations.  I.e. set enumeration_model_updates_permitted = true
        def enumeration_model_update
          if self.class.enumeration_model_updates_permitted    
            self.class.purge_enumerations_cache
            true
          else
            # Ugh.  This just seems hack-ish.  I wonder if there's a better way.
            self.errors.add(self.class.name_column, "changes to acts_as_enumeration model instances are not permitted")
            false
          end
        end
        private :enumeration_model_update
      end
    end
  end
end
        
