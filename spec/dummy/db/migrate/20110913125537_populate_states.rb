class PopulateStates < ActiveRecord::Migration
  def up
    State.enumeration_model_updates_permitted = true
    State.create!(:state_code => 'IL', :id => 1)
  end

  def down
    State.enumeration_model_updates_permitted = true
    State.destroy_all
  end
end
