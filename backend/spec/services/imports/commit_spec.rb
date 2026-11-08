require "rails_helper"

RSpec.describe Imports::Commit do
  def commit(batch, **options) = described_class.call(batch:, actor: "hr@acme.test", **options)

  let(:rows) do
    [
      import_row,
      import_row("effective_from" => "2025-01-01", "department" => "Sales", "base_pay" => "1200", "gross" => "1200", "net" => "1050"),
      import_row("employee_number" => "E2", "name" => "Ben Smith", "country" => "US", "currency" => "USD", "deductions" => "", "net" => "1000")
    ]
  end

  it "creates employees, department history and salary records with their deductions" do
    batch = commit(stage(rows))

    expect(batch).to be_committed
    expect(Employee.pluck(:employee_number)).to contain_exactly("E1", "E2")
    asha = Employee.find_by!(employee_number: "E1")
    expect(asha.assignments.order(:effective_from).pluck(:department)).to eq(%w[Engineering Sales])
    record = asha.salary_records.find_by!(effective_from: "2024-01-01")
    expect(record).to have_attributes(base_pay: 1000, net: 850, created_by: "hr@acme.test", import_batch: batch)
    expect(record.deduction_lines.pluck(:label, :amount)).to eq([["Income tax", 150]])
  end

  it "reuses an employee that already exists in the system" do
    existing = create(:employee, employee_number: "E1", name: "Asha Rao")
    commit(stage([import_row]))

    expect(Employee.where(employee_number: "E1").count).to eq(1)
    expect(existing.salary_records.count).to eq(1)
  end

  it "loads nothing if any row cannot be loaded (all or nothing)" do
    batch = stage(rows)
    # Someone adds a conflicting salary by hand after staging.
    create(:salary_record, employee: create(:employee, employee_number: "E2", name: "Ben Smith"), effective_from: Date.new(2024, 1, 1))

    expect { commit(batch) }.to raise_error(AppErrors::Conflict, /Row 4.*Nothing was loaded/)
    expect(Employee.pluck(:employee_number)).to eq(["E2"])
    expect(SalaryRecord.where(import_batch: batch)).to be_empty
    expect(batch.reload.status).to eq("staged")
  end

  it "cannot be committed twice" do
    batch = commit(stage([import_row]))
    expect { commit(batch) }.to raise_error(AppErrors::Conflict, /already committed/)
    expect(SalaryRecord.count).to eq(1)
  end

  context "when some rows were rejected" do
    let(:batch) { stage([import_row, import_row("employee_number" => "E2", "net" => "1")]) }

    it "asks for confirmation before loading only the good rows" do
      expect { commit(batch) }.to raise_error(AppErrors::BadRequest, /1 rows were rejected/)
      expect(Employee.count).to eq(0)
    end

    it "loads only the accepted rows once confirmed" do
      commit(batch, confirm_rejected: true)
      expect(Employee.pluck(:employee_number)).to eq(["E1"])
    end
  end

  it "audits the commit" do
    commit(stage([import_row]))
    expect(AuditEvent.find_by!(action: "import.committed").details).to include("loaded_rows" => 1)
  end
end
