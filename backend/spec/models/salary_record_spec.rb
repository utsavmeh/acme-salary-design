require "rails_helper"

RSpec.describe SalaryRecord do
  describe "validations" do
    it "is valid when net equals gross minus all deductions" do
      record = build(:salary_record, gross: 1000, net: 800)
      record.deduction_lines.clear
      record.deduction_lines.build(label: "Tax", amount: 150)
      record.deduction_lines.build(label: "Pension", amount: 50)
      expect(record).to be_valid
    end

    it "is invalid when net does not match gross minus deductions" do
      record = build(:salary_record, net: 900)
      expect(record).not_to be_valid
      expect(record.errors[:net].first).to include("expected 850")
    end

    it "rejects negative amounts" do
      expect(build(:salary_record, base_pay: -1)).not_to be_valid
    end

    it "requires an uppercase 3-letter currency" do
      expect(build(:salary_record, currency: "inr")).not_to be_valid
    end

    it "does not allow a negative deduction" do
      expect(DeductionLine.new(label: "Tax", amount: -5)).not_to be_valid
    end
  end

  describe "immutability" do
    let!(:record) { create(:salary_record) }

    it "cannot be updated once saved" do
      expect { record.update!(base_pay: 2000) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "cannot be destroyed" do
      expect(record.destroy).to be(false)
      expect(described_class.count).to eq(1)
    end

    it "keeps deduction lines read-only too" do
      expect { record.deduction_lines.first.update!(amount: 1) }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end

  describe "versioning" do
    let(:employee) { create(:employee) }

    it "does not allow two rows with the same employee, date and version" do
      create(:salary_record, employee:)
      expect { create(:salary_record, employee:) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    describe ".effective" do
      it "hides a row that has been superseded by a higher version" do
        old = create(:salary_record, employee:, version: 1)
        corrected = create(:salary_record, employee:, version: 2, base_pay: 1100, gross: 1100, net: 950)
        expect(described_class.effective).to contain_exactly(corrected)
        expect(described_class.effective).not_to include(old)
      end
    end

    describe ".current_as_of" do
      before do
        create(:salary_record, employee:, effective_from: Date.new(2023, 1, 1), base_pay: 900)
        create(:salary_record, employee:, effective_from: Date.new(2024, 1, 1), base_pay: 1000)
      end

      it "returns the latest record on or before the date" do
        expect(described_class.current_as_of(Date.new(2023, 6, 1)).map(&:base_pay)).to eq([900])
        expect(described_class.current_as_of(Date.new(2024, 1, 1)).map(&:base_pay)).to eq([1000])
      end

      it "returns nothing for an employee who has no record yet on that date" do
        expect(described_class.current_as_of(Date.new(2022, 1, 1))).to be_empty
      end

      it "returns one row per employee" do
        other = create(:employee)
        create(:salary_record, employee: other, effective_from: Date.new(2023, 5, 1))
        expect(described_class.current_as_of(Date.new(2024, 6, 1)).map(&:employee_id)).to contain_exactly(employee.id, other.id)
      end
    end
  end
end
