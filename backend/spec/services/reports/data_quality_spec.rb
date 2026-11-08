require "rails_helper"

RSpec.describe Reports::DataQuality do
  let(:today) { Date.new(2025, 6, 30) }
  let(:result) { described_class.new({}, today:).call }

  before do
    rate("INR", 2025, "0.01")
    pay(employee_in("Engineering", number: "OK"), 1000)
  end

  it "is empty when the data is complete" do
    expect(result).to include(employees_without_salary: [], employees_without_department: [], missing_rates: [])
  end

  it "lists active employees who have no salary record" do
    create(:employee, employee_number: "NOPAY", name: "No Pay")
    create(:employee, employee_number: "GONE", status: "inactive")

    expect(result[:employees_without_salary].map { |e| e[:employee_number] }).to eq(["NOPAY"])
  end

  it "lists employees who have pay but no department" do
    pay(create(:employee, employee_number: "NODEPT"), 500)
    expect(result[:employees_without_department].map { |e| e[:employee_number] }).to eq(["NODEPT"])
  end

  it "lists currency and year pairs that have pay but no rate" do
    pay(employee_in("Sales", number: "JP1", country: "JP"), 400_000, currency: "JPY")
    expect(result[:missing_rates]).to eq([{ currency: "JPY", year: 2025, amounts_affected: 1 }])
  end
end
