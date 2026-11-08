require "rails_helper"

RSpec.describe Reports::PaySummary do
  let(:today) { Date.new(2025, 6, 30) }

  def run(params = {}) = described_class.new(params, today:).call
  def group(result, name) = result[:groups].find { |g| g[:group] == name }

  before do
    rate("INR", 2025, "0.01")
    pay(employee_in("Engineering", number: "E1"), 1000)
    pay(employee_in("Engineering", number: "E2"), 3000)
    pay(employee_in("Sales", number: "E3", country: "US"), 2000, currency: "USD")
  end

  it "summarises pay per department in USD with the original amounts next to it" do
    engineering = group(run, "Engineering")

    expect(engineering).to include(headcount: 2, unit: "USD", total: "40.00", average: "20.00", lowest: "10.00", highest: "30.00")
    expect(engineering[:original_amounts]).to eq([{ currency: "INR", headcount: 2, total_base_pay: "4000.00" }])
    expect(group(run, "Sales")).to include(total: "2000.00")
  end

  it "states which rates it used" do
    expect(run[:rates_used]).to eq([{ currency: "INR", year: 2025, rate_to_usd: "0.01" }])
  end

  it "groups by country or by nothing" do
    expect(run(group_by: "country")[:groups].map { |g| g[:group] }).to eq(%w[IN US])
    expect(run(group_by: "none")[:groups].first).to include(headcount: 3)
  end

  it "reports a missing rate instead of guessing, and leaves those people out of the totals" do
    pay(employee_in("Engineering", number: "E4", country: "JP"), 500_000, currency: "JPY")
    result = run
    engineering = group(result, "Engineering")

    expect(engineering).to include(headcount: 3, counted: 2, excluded_for_missing_rate: 1, total: "40.00")
    expect(result[:missing_rates]).to eq([{ currency: "JPY", year: 2025, amounts_affected: 1 }])
  end

  it "does not use another year's rate when the year has none" do
    result = described_class.new({ as_of: "2026-03-01" }, today:).call
    expect(group(result, "Engineering")).to include(counted: 0, total: "0.00", average: nil)
    expect(result[:missing_rates]).to include(a_hash_including(currency: "INR", year: 2026))
  end

  it "uses the pay in force on the as_of date" do
    pay(Employee.find_by!(employee_number: "E1"), 2000, from: Date.new(2025, 7, 1))

    expect(group(run(as_of: "2025-06-30"), "Engineering")).to include(total: "40.00")
    expect(group(run(as_of: "2025-07-01"), "Engineering")).to include(total: "50.00")
  end

  it "ignores inactive employees" do
    pay(employee_in("Engineering", number: "E9", status: "inactive"), 9000)
    expect(group(run, "Engineering")).to include(headcount: 2)
  end

  describe "native currency mode" do
    it "shows plain amounts when the results are in one currency" do
      result = run(currency_mode: "native", country: "IN")
      expect(group(result, "Engineering")).to include(unit: "INR", total: "4000.00")
      expect(result[:rates_used]).to be_empty
    end

    it "refuses to mix currencies" do
      expect { run(currency_mode: "native") }.to raise_error(AppErrors::BadRequest, /single currency/)
    end

    it "needs no exchange rate at all" do
      ExchangeRate.delete_all
      expect(run(currency_mode: "native", country: "IN")[:missing_rates]).to be_empty
    end
  end

  it "rejects an unknown mode, grouping or date" do
    expect { run(currency_mode: "eur") }.to raise_error(AppErrors::BadRequest)
    expect { run(group_by: "shoe_size") }.to raise_error(AppErrors::BadRequest)
    expect { run(as_of: "yesterday") }.to raise_error(AppErrors::BadRequest)
  end

  it "filters by department" do
    expect(run(department: "Sales")[:groups].map { |g| g[:group] }).to eq(["Sales"])
  end
end
