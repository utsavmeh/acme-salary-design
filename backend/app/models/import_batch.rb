# One uploaded Excel/CSV file moving through: staged (checked, nothing loaded) -> committed.
class ImportBatch < ApplicationRecord
  STATUSES = %w[staged committed].freeze

  has_many :import_rows, dependent: :restrict_with_error
  has_many :salary_records, dependent: nil

  validates :filename, :file_sha256, :uploaded_by, presence: true
  validates :status, inclusion: { in: STATUSES }

  def committed? = status == "committed"
end
