# Short helpers so report specs read like the scenario they describe.
module PayHelpers
  def employee_in(department, number:, country: "IN", title: "Developer", status: "active")
    employee = create(:employee, employee_number: number, name: "Person #{number}", country:, status:)
    create(:assignment, employee:, department:, job_title: title, effective_from: Date.new(2020, 1, 1))
    employee
  end

  # A salary record with one fixed 150 deduction, so net is always base_pay - 150.
  def pay(employee, base_pay, from: Date.new(2024, 1, 1), currency: "INR", country: employee.country, **attrs)
    create(:salary_record, employee:, base_pay:, gross: base_pay, net: base_pay - 150,
                           effective_from: from, currency:, country:, **attrs)
  end

  def rate(currency, year, value)
    create(:exchange_rate, currency:, year:, rate_to_usd: value)
  end
end

RSpec.configure { |config| config.include PayHelpers }
