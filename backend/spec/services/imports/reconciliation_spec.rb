require "rails_helper"

RSpec.describe Imports::Reconciliation do
  let(:rows) do
    [
      import_row,                                                                                     # INR 1000 / 850, accepted
      import_row("employee_number" => "E2", "base_pay" => "2000", "gross" => "2000", "net" => "1850"), # INR 2000 / 1850, accepted
      import_row("employee_number" => "E3", "net" => "999"),                                          # INR 1000 / 999, rejected (net mismatch)
      import_row("employee_number" => "E4", "currency" => "USD", "gross" => "500", "deductions" => "", "net" => "500", "base_pay" => "500")
    ]
  end
  let(:batch) { stage(rows) }

  def line(report, currency) = report[:currencies].find { |l| l[:currency] == currency }

  it "shows file, accepted and rejected totals per currency" do
    inr = line(described_class.call(batch), "INR")

    expect(inr[:file]).to eq(rows: 3, gross: "4000.00", net: "3699.00")
    expect(inr[:accepted]).to eq(rows: 2, gross: "3000.00", net: "2700.00")
    expect(inr[:rejected]).to eq(rows: 1, gross: "1000.00", net: "999.00")
    expect(line(described_class.call(batch), "USD")[:file]).to eq(rows: 1, gross: "500.00", net: "500.00")
  end

  it "balances: file = accepted + rejected, so no row was lost" do
    report = described_class.call(batch)
    expect(report).to include(balanced: true, rows: { in_file: 4, accepted: 3, rejected: 1 })
  end

  it "has no 'loaded' figures before commit" do
    report = described_class.call(batch)
    expect(line(report, "INR")[:loaded]).to be_nil
    expect(report[:loaded_matches_accepted]).to be_nil
  end

  it "after commit, proves that what was loaded equals what was accepted" do
    Imports::Commit.call(batch:, actor: "hr@acme.test", confirm_rejected: true)
    report = described_class.call(batch.reload)

    expect(line(report, "INR")[:loaded]).to eq(rows: 2, gross: "3000.00", net: "2700.00")
    expect(report[:loaded_matches_accepted]).to be(true)
  end

  it "detects when loaded data no longer matches (for example a lost row)" do
    Imports::Commit.call(batch:, actor: "hr@acme.test", confirm_rejected: true)
    SalaryRecord.connection.execute("DELETE FROM deduction_lines WHERE salary_record_id IN (SELECT id FROM salary_records WHERE import_batch_id = #{batch.id} LIMIT 1)")
    SalaryRecord.connection.execute("DELETE FROM salary_records WHERE id = (SELECT MIN(id) FROM salary_records WHERE import_batch_id = #{batch.id})")

    expect(described_class.call(batch.reload)[:loaded_matches_accepted]).to be(false)
  end

  it "counts rows whose amounts cannot be read instead of hiding them" do
    batch = stage([import_row("gross" => "abc", "base_pay" => "abc")])
    expect(line(described_class.call(batch), "INR")[:unreadable_amount_rows]).to eq(1)
  end
end
