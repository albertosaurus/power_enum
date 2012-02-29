class CreateAdapters < ActiveRecord::Migration
  def change
    create_table :adapters do |t|
      t.integer :connector_type_id

      t.timestamps
    end
  end
end
