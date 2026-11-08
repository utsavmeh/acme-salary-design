# A person on ACME's payroll. Employees are never deleted, only marked inactive.
class Employee < ApplicationRecord
  STATUSES = %w[active inactive].freeze

  has_many :assignments, dependent: :restrict_with_error
  has_many :salary_records, dependent: :restrict_with_error

  validates :employee_number, :name, :hire_date, presence: true
  validates :employee_number, uniqueness: true
  validates :country, format: { with: /\A[A-Z]{2}\z/, message: "must be a 2-letter uppercase country code" }
  validates :status, inclusion: { in: STATUSES }

  # The department/title in force on a given date (nil if none was recorded yet).
  def assignment_on(date)
    assignments.select { |a| a.effective_from <= date }.max_by(&:effective_from)
  end
end
