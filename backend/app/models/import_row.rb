# One row of an uploaded file, exactly as read (`raw`) plus the cleaned values (`data`) when it
# was accepted, or the reasons it was rejected.
class ImportRow < ApplicationRecord
  belongs_to :import_batch

  scope :accepted, -> { where(status: "accepted") }
  scope :rejected, -> { where(status: "rejected") }
end
