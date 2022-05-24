class Provider < ApplicationRecord
  self.inheritance_column = :_disabled
end
