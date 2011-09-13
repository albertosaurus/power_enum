class AddBookingStatuses < ActiveRecord::Migration
  def up
    BookingStatus.enumeration_model_updates_permitted = true
    BookingStatus.create!(:name => 'confirmed', :id => 1)
    BookingStatus.create!(:name => 'received' , :id => 2)
    BookingStatus.create!(:name => 'rejected' , :id => 3)
  end

  def down
    BookingStatus.destroy_all
  end
end
