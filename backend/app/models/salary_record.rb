# Monthly pay terms of an employee from `effective_from` onwards, in the employee's own currency.
#
# Records are append-only: they are never edited or deleted. A correction is stored as a
# new row with the same `effective_from` and a higher `version`; the highest version wins.
class SalaryRecord < ApplicationRecord
  belongs_to :employee
  belongs_to :import_batch, optional: true # set for rows loaded by the Excel migration
  has_many :deduction_lines, dependent: nil

  validates :currency, format: { with: /\A[A-Z]{3}\z/, message: "must be a 3-letter uppercase currency code" }
  validates :country, format: { with: /\A[A-Z]{2}\z/, message: "must be a 2-letter uppercase country code" }
  validates :base_pay, :gross, :net, numericality: { greater_than_or_equal_to: 0 }
  validates :effective_from, :created_by, presence: true
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validate :net_matches_gross_minus_deductions

  before_destroy { throw :abort }

  # Rows that are not superseded by a higher version for the same date.
  scope :effective, lambda {
    where(<<~SQL.squish)
      salary_records.version = (
        SELECT MAX(v.version) FROM salary_records v
        WHERE v.employee_id = salary_records.employee_id AND v.effective_from = salary_records.effective_from
      )
    SQL
  }

  # Each employee's effective record in force on `date`.
  scope :current_as_of, lambda { |date|
    effective.where("salary_records.effective_from <= ?", date).where(<<~SQL.squish, date)
      salary_records.effective_from = (
        SELECT MAX(s.effective_from) FROM salary_records s
        WHERE s.employee_id = salary_records.employee_id AND s.effective_from <= ?
      )
    SQL
  }

  # { employee_id => record } for the employees' records in force on `date`.
  def self.current_by_employee(employee_ids, date = Date.current)
    current_as_of(date).where(employee_id: employee_ids).includes(:deduction_lines).index_by(&:employee_id)
  end

  def readonly? = persisted? || super

  def deductions_total
    deduction_lines.sum { |line| line.amount || 0 }
  end

  private

  def net_matches_gross_minus_deductions
    return if gross.nil? || net.nil?

    expected = gross - deductions_total
    return if expected == net

    errors.add(:net, "must equal gross minus deductions (expected #{expected.to_s('F')})")
  end
end
