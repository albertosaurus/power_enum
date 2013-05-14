# Copyright (c) 2005 Trevor Squires
# Copyright (c) 2012 Arthur Shagall
# Released under the MIT License.  See the LICENSE file for more details.

# Implementation of acts_as_enumerated
module PowerEnum::Enumerated
  extend ActiveSupport::Concern

  # Class level methods injected into ActiveRecord.
  module ClassMethods

    # Returns false for ActiveRecord models that do not act as enumerated.
    def acts_as_enumerated?
      false
    end

    # Declares the model as enumerated.  See the README for detailed usage instructions.
    #
    # === Supported options
    # [:conditions]
    #   SQL search conditions
    # [:order]
    #   SQL load order clause
    # [:on_lookup_failure]
    #   Specifies the name of a class method to invoke when the +[]+ method is unable to locate a BookingStatus
    #   record for arg. The default is the built-in :enforce_none which returns nil. There are also built-ins for
    #   :enforce_strict (raise and exception regardless of the type for arg), :enforce_strict_literals (raises an
    #   exception if the arg is a Fixnum or Symbol), :enforce_strict_ids (raises and exception if the arg is a
    #   Fixnum) and :enforce_strict_symbols (raises an exception if the arg is a Symbol).  The purpose of the
    #   :on_lookup_failure option is that a) under some circumstances a lookup failure is a Bad Thing and action
    #   should be taken, therefore b) a fallback action should be easily configurable.  You can also give it a
    #   lambda that takes in a single argument (The arg that was passed to +[]+).
    # [:name_column]
    #   Override for the 'name' column.  By default, assumed to be 'name'.
    # [:alias_name]
    #   By default, if a name column is not 'name', will create an alias of 'name' to the name_column attribute.  Set
    #   this to +false+ if you don't want this behavior.
    #
    # === Examples
    #
    # ====Example 1
    #  class BookingStatus < ActiveRecord::Base
    #    acts_as_enumerated
    #  end
    #
    # ====Example 2
    #  class BookingStatus < ActiveRecord::Base
    #    acts_as_enumerated :on_lookup_failure => :enforce_strict
    #  end
    #
    # ====Example 3
    #  class BookingStatus < ActiveRecord::Base
    #    acts_as_enumerated :conditions        => [:exclude => false],
    #                       :order             => 'created_at DESC',
    #                       :on_lookup_failure => :lookup_failed,
    #                       :name_column       => :status_code
    #
    #    def self.lookup_failed(arg)
    #      logger.error("Invalid status code lookup #{arg.inspect}")
    #      nil
    #    end
    #  end
    #
    # ====Example 4
    #  class BookingStatus < ActiveRecord::Base
    #    acts_as_enumerated :conditions        => [:exclude => false],
    #                       :order             => 'created_at DESC',
    #                       :on_lookup_failure => lambda { |arg| raise CustomError, "BookingStatus lookup failed; #{arg}" },
    #                       :name_column       => :status_code
    #  end
    def acts_as_enumerated(options = {})
      valid_keys = [:conditions, :order, :on_lookup_failure, :name_column, :alias_name]
      options.assert_valid_keys(*valid_keys)

      valid_keys.each do |key|
        class_attribute "acts_enumerated_#{key.to_s}"
        if options.has_key?( key )
          self.send "acts_enumerated_#{key.to_s}=", options[key]
        end
      end

      class_attribute :acts_enumerated_name_column
      self.acts_enumerated_name_column = get_name_column(options)

      unless self.is_a? PowerEnum::Enumerated::EnumClassMethods
        extend_enum_class_methods( options )
      end
    end

    # Injects the class methods into model
    def extend_enum_class_methods(options) #:nodoc:
      extend PowerEnum::Enumerated::EnumClassMethods

      class_eval do
        include PowerEnum::Enumerated::EnumInstanceMethods

        before_save :enumeration_model_update
        before_destroy :enumeration_model_update
        validates acts_enumerated_name_column, :presence => true, :uniqueness => true

        define_method :__enum_name__ do
          read_attribute(acts_enumerated_name_column).to_s
        end

        if should_alias_name?(options) && acts_enumerated_name_column != :name
          alias_method :name, :__enum_name__
        end
      end # class_eval

    end
    private :extend_enum_class_methods

    # Determines if the name column should be explicitly aliased
    def should_alias_name?(options) #:nodoc:
      if options.has_key?(:alias_name) then
        options[:alias_name]
      else
        true
      end
    end
    private :should_alias_name?

    # Extracts the name column from options or gives the default
    def get_name_column(options) #:nodoc:
      if options.has_key?(:name_column) && !options[:name_column].blank? then
        options[:name_column].to_s.to_sym
      else
        :name
      end
    end
    private :get_name_column
  end

  # These are class level methods which are patched into classes that act as
  # enumerated
  module EnumClassMethods
    attr_accessor :enumeration_model_updates_permitted

    # Returns true for ActiveRecord models that act as enumerated.
    def acts_as_enumerated?
      true
    end

    # Returns all the enum values.  Caches results after the first time this method is run.
    def all
      return @all if @all
      @all = load_all.collect{|val| val.freeze}.freeze
    end

    # Returns all the active enum values.  See the 'active?' instance method.
    def active
      return @all_active if @all_active
      @all_active = all.find_all{ |enum| enum.active? }.freeze
    end

    # Returns all the inactive enum values.  See the 'inactive?' instance method.
    def inactive
      return @all_inactive if @all_inactive
      @all_inactive = all.find_all{ |enum| !enum.active? }.freeze
    end

    # Returns the names of all the enum values as an array of symbols.
    def names
      all.map { |item| item.name_sym }
    end

    # Enum lookup by Symbol, String, or id.  Returns <tt>arg<tt> if arg is
    # an enum instance.  Passing in a list of arguments returns a list of
    # enums.  When called with no arguments, returns nil.
    def [](*args)
      case args.size
      when 0
        nil
      when 1
        arg = args.first
        lookup_enum_by_type(arg) || handle_lookup_failure(arg)
      else
        args.map{ |item| self[item] }.uniq
      end
    end

    # Returns <tt>true</tt> if the given Symbol, String or id has a member
    # instance in the enumeration, <tt>false</tt> otherwise.  Returns <tt>true</tt>
    # if the argument is an enum instance, returns <tt>false</tt> if the argument
    # is nil or any other value.
    def contains?(arg)
      case arg
      when Symbol
        !!lookup_name(arg.id2name)
      when String
        !!lookup_name(arg)
      when Fixnum
        !!lookup_id(arg)
      when self
        true
      else
        false
      end
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

    # The preferred method to update an enumerations model.  The same
    # warnings as 'purge_enumerations_cache' and
    # 'enumerations_model_update_permitted' apply.  Pass a block to this
    # method where you perform your updates.  Cache will be
    # flushed automatically.  If your block takes an argument, will pass in
    # the model class.  The argument is optional.
    def update_enumerations_model(&block)
      if block_given?
        begin
          self.enumeration_model_updates_permitted = true
          purge_enumerations_cache
          @all = load_all
          @enumerations_model_updating = true
          case block.arity
          when 0
            yield
          else
            yield self
          end
        ensure
          purge_enumerations_cache
          @enumerations_model_updating = false
          self.enumeration_model_updates_permitted = false
        end
      end
    end

    # Returns true if the enumerations model is in the middle of an
    # update_enumerations_model block, false otherwise.
    def enumerations_model_updating?
      !!@enumerations_model_updating
    end

    # Returns the name of the column this enum uses as the basic underlying value.
    def name_column
      @name_column ||= self.acts_enumerated_name_column
    end

    # ---Private methods---

    def load_all
      conditions = self.acts_enumerated_conditions
      order      = self.acts_enumerated_order
      unscoped.where(conditions).order(order)
    end
    private :load_all

    # Looks up the enum based on the type of the argument.
    def lookup_enum_by_type(arg)
      case arg
      when Symbol
        lookup_name(arg.id2name)
      when String
        lookup_name(arg)
      when Fixnum
        lookup_id(arg)
      when self
        arg
      when nil
        nil
      else
        raise TypeError, "#{self.name}[]: argument should"\
                         " be a String, Symbol or Fixnum but got a: #{arg.class.name}"
      end
    end
    private :lookup_enum_by_type

    # Deals with a lookup failure for the given argument.
    def handle_lookup_failure(arg)
      if (lookup_failure_handler = self.acts_enumerated_on_lookup_failure)
        case lookup_failure_handler
        when Proc
          lookup_failure_handler.call(arg)
        else
          self.send(lookup_failure_handler, arg)
        end
      else
        self.send(:enforce_none, arg)
      end
    end
    private :handle_lookup_failure

    # Returns a hash of all enumeration members keyed by their ids.
    def all_by_id
      @all_by_id ||= all_by_attribute( :id )
    end
    private :all_by_id

    # Returns a hash of all the enumeration members keyed by their names.
    def all_by_name
      begin
        @all_by_name ||= all_by_attribute( :__enum_name__ )
      rescue NoMethodError => err
        if err.name == name_column
          raise TypeError, "#{self.name}: you need to define a '#{name_column}' column in the table '#{table_name}'"
        end
        raise
      end
    end
    private :all_by_name

    def all_by_attribute(attr) # :nodoc:
      aba = all.inject({}) { |memo, item|
        memo[item.send(attr)] = item
        memo
      }
      aba.freeze unless enumerations_model_updating?
      aba
    end
    private :all_by_attribute

    def enforce_none(arg) # :nodoc:
      nil
    end
    private :enforce_none

    def enforce_strict(arg) # :nodoc:
      raise_record_not_found(arg)
    end
    private :enforce_strict

    def enforce_strict_literals(arg) # :nodoc:
      raise_record_not_found(arg) if (Fixnum === arg) || (Symbol === arg)
      nil
    end
    private :enforce_strict_literals

    def enforce_strict_ids(arg) # :nodoc:
      raise_record_not_found(arg) if Fixnum === arg
      nil
    end
    private :enforce_strict_ids

    def enforce_strict_symbols(arg) # :nodoc:
      raise_record_not_found(arg) if Symbol === arg
      nil
    end
    private :enforce_strict_symbols

    # raise the {ActiveRecord::RecordNotFound} error.
    # @private
    def raise_record_not_found(arg)
      raise ActiveRecord::RecordNotFound, "Couldn't find a #{self.name} identified by (#{arg.inspect})"
    end
    private :raise_record_not_found

  end

  # These are instance methods for objects which are enums.
  module EnumInstanceMethods
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
    # You should note that defining an +:on_lookup_failure+ method that raises an exception will cause +===+ to
    # also raise an exception for any lookup failure of +BookingStatus[arg]+.
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
      self.__enum_name__.to_sym
    end

    alias_method :to_sym, :name_sym

    # By default enumeration #to_s should return stringified name of the enum. BookingStatus[:foo].to_s returns "foo"
    def to_s
      self.__enum_name__
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
  end # module EnumInstanceMethods
end # module PowerEnum::Enumerated
