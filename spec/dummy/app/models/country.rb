class Country < ActiveRecord::Base
  acts_as_enumerated :name_column => :code
end
