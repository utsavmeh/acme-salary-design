# Department and job title of an employee from a given date onwards.
# Kept as history so reports about the past use the department of that time.
class Assignment < ApplicationRecord
  belongs_to :employee

  validates :department, :job_title, :effective_from, presence: true
  validates :effective_from, uniqueness: { scope: :employee_id }
end
