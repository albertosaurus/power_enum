class State < ActiveRecord::Base
  acts_as_enumerated :name_column => :state_code
end
