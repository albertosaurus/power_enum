class PopulateCountries < ActiveRecord::Migration
  def up
    Country.enumeration_model_updates_permitted = true
    Country.create!(:name => "Ukraine", :code => "ua")
  end

  def down
    Country.enumeration_model_updates_permitted = true
    Country.destroy_all
  end
end
