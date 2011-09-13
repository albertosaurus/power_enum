class AddStateIdToBooking < ActiveRecord::Migration

  def up
    change_table :bookings do |t|
      t.integer :state_id
    end
  end

  def down
    remove_column :bookings, :state_id
  end
end
