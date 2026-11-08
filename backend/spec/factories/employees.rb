FactoryBot.define do
  factory :employee do
    sequence(:employee_number) { |n| format("E%05d", n) }
    sequence(:name) { |n| "Employee #{n}" }
    country { "IN" }
    hire_date { Date.new(2020, 1, 1) }
    status { "active" }
  end

  factory :assignment do
    employee
    department { "Engineering" }
    job_title { "Developer" }
    effective_from { Date.new(2020, 1, 1) }
  end
end
