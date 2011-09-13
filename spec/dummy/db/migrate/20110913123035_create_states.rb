class CreateStates < ActiveRecord::Migration
  def change
    create_table :states do |t|
      t.string :state_code

      t.timestamps
    end
  end
end
