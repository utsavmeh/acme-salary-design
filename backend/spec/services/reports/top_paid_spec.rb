require "rails_helper"

RSpec.describe Reports::TopPaid do
  let(:today) { Date.new(2025, 6, 30) }

  def run(params = {}) = described_class.new(params, today:).call

  before do
    rate("INR", 2025, "0.01")
    pay(employee_in("Engineering", number: "E1"), 150_000)                              # 1,500 USD
    pay(employee_in("Engineering", number: "E2", country: "US"), 2000, currency: "USD")  # 2,000 USD
    pay(employee_in("Sales", number: "E3"), 100_000)                                     # 1,000 USD
  end

  it "ranks people across currencies by their USD value, showing the original amount" do
    rows = run[:rows]

    expect(rows.map { |r| r[:employee_number] }).to eq(%w[E2 E1 E3])
    expect(rows.first).to include(rank: 1, base_pay: "2000.00", unit: "USD", original_currency: "USD")
    expect(rows.second).to include(base_pay: "1500.00", original_currency: "INR", original_base_pay: "150000.00")
  end

  it "finds the highest paid in one department" do
    expect(run(department: "Sales", limit: 1)[:rows].map { |r| r[:employee_number] }).to eq([ "E3" ])
  end

  it "respects the limit" do
    expect(run(limit: 2)[:rows].size).to eq(2)
  end

  it "breaks ties by employee number so the order is stable" do
    pay(employee_in("Engineering", number: "E0", country: "US"), 2000, currency: "USD")
    expect(run[:rows].first(2).map { |r| r[:employee_number] }).to eq(%w[E0 E2])
  end

  it "leaves out people whose currency has no rate and reports the gap" do
    pay(employee_in("Engineering", number: "E4", country: "JP"), 9_000_000, currency: "JPY")
    result = run

    expect(result[:rows].map { |r| r[:employee_number] }).not_to include("E4")
    expect(result[:missing_rates]).to eq([ { currency: "JPY", year: 2025, amounts_affected: 1 } ])
  end

  it "ranks by plain amounts in native mode for one currency" do
    rows = run(currency_mode: "native", country: "IN")[:rows]
    expect(rows.map { |r| r[:employee_number] }).to eq(%w[E1 E3])
    expect(rows.first).to include(unit: "INR", base_pay: "150000.00")
  end
end
