# One recorded deduction (e.g. "Income tax") on a salary record. Recorded, never calculated.
class DeductionLine < ApplicationRecord
  belongs_to :salary_record

  validates :label, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  def readonly? = persisted? || super
end
