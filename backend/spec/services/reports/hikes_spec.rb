require "rails_helper"

RSpec.describe Reports::Hikes do
  let(:today) { Date.new(2025, 12, 31) }

  def run(params = {}) = described_class.new({ year: 2025 }.merge(params), today:).call
  def numbers(result) = result[:rows].map { |r| r[:employee_number] }

  before do
    rate("INR", 2025, "0.01")

    @a = employee_in("Engineering", number: "A")          # 1000 -> 1200 : +20%, +200 INR (2 USD)
    pay(@a, 1000, from: Date.new(2023, 1, 1))
    pay(@a, 1200, from: Date.new(2025, 3, 1))

    @b = employee_in("Engineering", number: "B", country: "US") # 2000 -> 2200 USD: +10%, +200 USD
    pay(@b, 2000, from: Date.new(2024, 1, 1), currency: "USD")
    pay(@b, 2200, from: Date.new(2025, 1, 1), currency: "USD")
  end

  it "ranks the biggest percentage increases of the year with full details" do
    result = run

    expect(numbers(result)).to eq(%w[A B])
    expect(result[:rows].first).to include(
      rank: 1, name: "Person A", department: "Engineering", effective_from: Date.new(2025, 3, 1), currency: "INR",
      old_base_pay: "1000.00", new_base_pay: "1200.00", increase: "200.00", percent_increase: "20.0", increase_usd: "2.00"
    )
  end

  it "does not let exchange rates change the percentage" do
    ExchangeRate.delete_all
    result = run

    expect(result[:rows].first).to include(percent_increase: "20.0", increase_usd: nil)
    expect(result[:missing_rates]).to eq([ { currency: "INR", year: 2025, amounts_affected: 1 } ])
  end

  it "can rank by absolute increase in USD instead" do
    expect(numbers(run(sort_by: "amount"))).to eq(%w[B A]) # 200 USD beats 2 USD
  end

  it "ignores pay cuts, unchanged pay and increases in other years" do
    cut = employee_in("Sales", number: "C")
    pay(cut, 1000, from: Date.new(2024, 1, 1))
    pay(cut, 900, from: Date.new(2025, 6, 1))
    old = employee_in("Sales", number: "D")
    pay(old, 1000, from: Date.new(2022, 1, 1))
    pay(old, 5000, from: Date.new(2024, 6, 1))

    expect(numbers(run)).to eq(%w[A B])
  end

  it "uses the corrected version of a record, not the superseded one" do
    wrong = employee_in("Sales", number: "E")
    pay(wrong, 1000, from: Date.new(2024, 1, 1))
    pay(wrong, 1100, from: Date.new(2025, 2, 1)) # 10% (wrong)
    pay(wrong, 2000, from: Date.new(2025, 2, 1), version: 2) # 100% (corrected)

    expect(numbers(run).first).to eq("E")
    expect(run[:rows].first).to include(percent_increase: "100.0")
  end

  it "counts a change of currency but does not rank it" do
    mover = employee_in("Sales", number: "F")
    pay(mover, 1000, from: Date.new(2024, 1, 1))
    pay(mover, 9000, from: Date.new(2025, 5, 1), currency: "USD", country: "US")

    result = run
    expect(numbers(result)).to eq(%w[A B])
    expect(result[:skipped_currency_changes]).to eq(1)
  end

  it "shows the department the person had when the hike took effect" do
    create(:assignment, employee: @a, department: "Sales", job_title: "Lead", effective_from: Date.new(2025, 9, 1))
    expect(run[:rows].first).to include(department: "Engineering")
  end

  it "respects the limit" do
    expect(run(limit: 1)[:rows].size).to eq(1)
  end

  it "requires a sensible year" do
    expect { described_class.new({}, today:).call }.to raise_error(AppErrors::BadRequest)
    expect { described_class.new({ year: "abc" }, today:).call }.to raise_error(AppErrors::BadRequest)
  end
end
