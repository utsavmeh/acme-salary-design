FactoryBot.define do
  factory :salary_record do
    employee
    currency { "INR" }
    country { "IN" }
    base_pay { 1000 }
    gross { 1000 }
    net { 850 }
    effective_from { Date.new(2024, 1, 1) }
    version { 1 }
    created_by { "hr@acme.test" }

    # One 150.00 deduction by default, so gross 1000 - 150 = net 850.
    after(:build) do |record|
      record.deduction_lines.build(label: "Income tax", amount: 150) if record.deduction_lines.empty?
    end
  end
end
