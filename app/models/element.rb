class Element < ApplicationRecord
  enum :unit,
       { day: 1, hour: 2, payment: 3, meal: 4, nights: 5,
                trip: 6, other_one_off: 6, unspecified: 7, unit: 8
       }
  enum :element_status,
       {
         in_progress: 0,
         awaiting_approval: 1,
         approved: 2,
         inactive: 3,
         active: 4,
         ended: 5,
         suspended: 6
       }
  belongs_to :care_package, optional: true
  belongs_to :provider, optional: true
  belongs_to :element_type
end
