require "rails_helper"

RSpec.describe SalaryRecordWriter do
  subject(:writer) { described_class.new(actor: "hr@acme.test") }

  let(:employee) { create(:employee, country: "IN") }
  let(:attrs) do
    { currency: "INR", base_pay: "1000", gross: "1000", net: "850", effective_from: "2024-01-01",
      deductions: [ { label: "Income tax", amount: "150" } ] }
  end

  describe "#create" do
    it "stores the record with its deductions and defaults the country to the employee's" do
      record = writer.create(employee, attrs)

      expect(record).to have_attributes(version: 1, country: "IN", created_by: "hr@acme.test", net: 850)
      expect(record.deduction_lines.map(&:label)).to eq([ "Income tax" ])
    end

    it "writes an audit event without copying pay amounts" do
      writer.create(employee, attrs)

      event = AuditEvent.find_by!(action: "salary_record.created")
      expect(event.details.keys).to contain_exactly("employee_id", "effective_from", "version")
    end

    it "refuses a second record for the same start date" do
      writer.create(employee, attrs)
      expect { writer.create(employee, attrs) }.to raise_error(AppErrors::Conflict)
      expect(SalaryRecord.count).to eq(1)
    end

    it "saves nothing and audits nothing when the record is invalid" do
      expect { writer.create(employee, attrs.merge(net: "999")) }.to raise_error(ActiveRecord::RecordInvalid)
      expect(SalaryRecord.count).to eq(0)
      expect(AuditEvent.where(action: "salary_record.created")).to be_empty
    end
  end

  describe "#correct" do
    let!(:original) { writer.create(employee, attrs) }

    it "adds a new version for the same date and keeps the old one" do
      corrected = writer.correct(original, base_pay: "1100", gross: "1100", net: "950")

      expect(corrected).to have_attributes(version: 2, effective_from: original.effective_from, base_pay: 1100)
      expect(SalaryRecord.where(employee:).count).to eq(2)
      expect(SalaryRecord.effective).to contain_exactly(corrected)
    end

    it "keeps the previous deductions when none are given" do
      corrected = writer.correct(original, base_pay: "1100", gross: "1000", net: "850")
      expect(corrected.deduction_lines.map { |l| [ l.label, l.amount ] }).to eq([ [ "Income tax", 150 ] ])
    end

    it "audits which fields changed, not their values" do
      writer.correct(original, base_pay: "1100", gross: "1100", net: "950")

      details = AuditEvent.find_by!(action: "salary_record.corrected").details
      expect(details["changed"]).to contain_exactly("base_pay", "gross", "net")
    end

    it "cannot move the effective date" do
      corrected = writer.correct(original, base_pay: "1100", gross: "1100", net: "950", effective_from: "2030-01-01")
      expect(corrected.effective_from).to eq(original.effective_from)
    end

    it "refuses to correct a version that has already been corrected" do
      writer.correct(original, base_pay: "1100", gross: "1100", net: "950")
      expect { writer.correct(original, base_pay: "1200", gross: "1200", net: "1050") }.to raise_error(AppErrors::Conflict)
    end
  end
end
