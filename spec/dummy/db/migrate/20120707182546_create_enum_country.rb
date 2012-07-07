class CreateEnumCountry < ActiveRecord::Migration

  def change
    create_enum(:country, :name_column => :code, :name_limit => 2) do |t|
      t.string :name, :null => false
    end
  end

end