require "rails_helper"

RSpec.describe Imports::RowValidator do
  def validate(overrides = {}) = described_class.call(import_row(overrides))
  def reasons(overrides) = validate(overrides).reasons

  it "accepts a valid row and returns typed values" do
    result = validate

    expect(result.reasons).to be_empty
    expect(result.data).to include(
      employee_number: "E1", country: "IN", currency: "INR", base_pay: BigDecimal("1000"), net: BigDecimal("850"),
      hire_date: Date.new(2020, 1, 1), effective_from: Date.new(2024, 1, 1),
      deductions: [{ label: "Income tax", amount: BigDecimal("150") }]
    )
  end

  it "upcases country and currency codes" do
    expect(validate("country" => "in", "currency" => "inr").data).to include(country: "IN", currency: "INR")
  end

  it "accepts a row with no deductions when net equals gross" do
    expect(validate("deductions" => "", "net" => "1000").reasons).to be_empty
  end

  it "accepts several deductions" do
    result = validate("deductions" => "Income tax:100;Pension:50.50", "net" => "849.50")
    expect(result.data[:deductions].map { |d| d[:label] }).to eq(["Income tax", "Pension"])
  end

  it "accepts an explicit monthly frequency and rejects any other" do
    expect(reasons("frequency" => "Monthly")).to be_empty
    expect(reasons("frequency" => "weekly")).to include(/only monthly pay is supported/)
  end

  it "lists every problem in a row, not just the first" do
    all = reasons("name" => "", "country" => "India", "base_pay" => "abc")
    expect(all).to include("name is missing", /country must be a 2-letter code/, /base_pay must be a plain number/)
  end

  it "rejects amounts with more than 2 decimals instead of rounding them" do
    expect(reasons("gross" => "1000.123")).to include(/gross must be a plain number with at most 2 decimals/)
  end

  it "rejects negative amounts, thousands separators and currency symbols" do
    ["-5", "1,000", "$1000"].each { |bad| expect(reasons("base_pay" => bad)).to include(/base_pay must be a plain number/) }
  end

  it "rejects ambiguous or impossible dates" do
    expect(reasons("hire_date" => "03/04/2020")).to include(/hire_date must be a date like 2024-01-31/)
    expect(reasons("effective_from" => "2024-02-30")).to include(/effective_from is not a real date/)
  end

  it "rejects net that does not equal gross minus deductions" do
    expect(reasons("net" => "900")).to include("net (900.0) does not equal gross (1000.0) minus deductions (150.0)")
  end

  it "rejects malformed deductions" do
    expect(reasons("deductions" => "Income tax 150")).to include(/deductions must look like/)
    expect(reasons("deductions" => "Tax:abc")).to include(/deduction 'Tax' must be a plain number/)
  end

  it "rejects a salary that starts before the hire date" do
    expect(reasons("hire_date" => "2025-01-01")).to include(/effective_from \(2024-01-01\) is before hire_date/)
  end
end
