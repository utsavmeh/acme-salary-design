require "rails_helper"

RSpec.describe ExchangeRate do
  describe ".record!" do
    def record(rate, reason: "Annual rate")
      described_class.record!(currency: "INR", year: 2024, rate_to_usd: rate, reason:, set_by: "rates@acme.test")
    end

    it "stores the first rate as version 1" do
      expect(record("0.012").version).to eq(1)
    end

    it "stores a correction as a new version and keeps the old row" do
      record("0.012")
      corrected = record("0.0119", reason: "Fixed typo")

      expect(corrected.version).to eq(2)
      expect(described_class.where(currency: "INR", year: 2024).count).to eq(2)
    end

    it "requires a reason" do
      expect { record("0.012", reason: "") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "refuses to set a rate for USD" do
      expect { described_class.record!(currency: "USD", year: 2024, rate_to_usd: 1, reason: "x", set_by: "a") }
        .to raise_error(ActiveRecord::RecordInvalid)
    end

    it "rejects zero and negative rates" do
      expect { record("0") }.to raise_error(ActiveRecord::RecordInvalid)
      expect { record("-1") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  it "cannot be edited after saving" do
    rate = create(:exchange_rate)
    expect { rate.update!(rate_to_usd: 5) }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  describe ".latest_versions" do
    it "returns only the highest version of each currency and year" do
      create(:exchange_rate, version: 1, rate_to_usd: "0.012")
      newest = create(:exchange_rate, version: 2, rate_to_usd: "0.0119")
      other_year = create(:exchange_rate, year: 2023, rate_to_usd: "0.0121")

      expect(described_class.latest_versions).to contain_exactly(newest, other_year)
    end
  end
end
