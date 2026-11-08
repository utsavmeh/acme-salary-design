require "rails_helper"

RSpec.describe RateBook do
  before do
    create(:exchange_rate, currency: "INR", year: 2024, version: 1, rate_to_usd: "0.012")
    create(:exchange_rate, currency: "INR", year: 2024, version: 2, rate_to_usd: "0.0125")
    create(:exchange_rate, currency: "EUR", year: 2023, rate_to_usd: "1.08")
  end

  subject(:book) { described_class.new }

  it "uses the latest version of a rate" do
    expect(book.rate_for("INR", 2024)).to eq(BigDecimal("0.0125"))
  end

  it "converts an amount to USD" do
    expect(book.to_usd(BigDecimal("80000"), "INR", 2024)).to eq(BigDecimal("1000"))
  end

  it "treats USD as 1 without needing a stored rate" do
    expect(book.to_usd(BigDecimal("500"), "USD", 2020)).to eq(500)
  end

  it "returns nil for a missing year instead of using another year's rate" do
    expect(book.rate_for("EUR", 2024)).to be_nil
    expect(book.to_usd(BigDecimal("100"), "EUR", 2024)).to be_nil
  end

  it "returns nil for a currency with no rate at all" do
    expect(book.to_usd(BigDecimal("100"), "JPY", 2024)).to be_nil
  end
end
