class BookingStatus < ActiveRecord::Base
  acts_as_enumerated :on_lookup_failure => :not_found

  # This method should be called when requested status does not exist
  def self.not_found(name)
  end
end
