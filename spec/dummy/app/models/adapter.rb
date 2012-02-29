require 'power_enum'

class Adapter < ActiveRecord::Base
  has_enumerated :connector_type
end
