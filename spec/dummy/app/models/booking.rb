require 'enumerations_mixin'

class Booking < ActiveRecord::Base
  has_enumerated  :status, :class_name        => 'BookingStatus',
                           :foreign_key       => :status_id,
                           :on_lookup_failure => :not_found_status_handler

  def not_found_status_handler(operation, name, foreign_key, acts_enumerated_class_name, lookup_value)
  end

  has_enumerated :state, :class_name => 'State'
end
