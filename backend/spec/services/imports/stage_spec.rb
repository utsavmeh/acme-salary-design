require "rails_helper"

RSpec.describe Imports::Stage do
  def rejected_reasons(batch) = batch.import_rows.rejected.order(:row_number).map(&:reasons)

  it "checks every row and counts accepted and rejected ones" do
    batch = stage([import_row, import_row("employee_number" => "E2", "net" => "1"), import_row("employee_number" => "E3")])

    expect(batch).to have_attributes(status: "staged", total_rows: 3, accepted_rows: 2, rejected_rows: 1, uploaded_by: "hr@acme.test")
    expect(batch.import_rows.rejected.first).to have_attributes(row_number: 3)
  end

  it "loads nothing into employees or salaries" do
    stage([import_row])
    expect([Employee.count, SalaryRecord.count]).to eq([0, 0])
  end

  it "keeps the original text of rejected rows for the report" do
    batch = stage([import_row("base_pay" => "abc", "gross" => "abc")])
    expect(batch.import_rows.first.raw).to include("base_pay" => "abc", "employee_number" => "E1")
  end

  it "rejects the second of two rows that give the same employee two salaries for one date" do
    batch = stage([import_row, import_row])
    expect(rejected_reasons(batch)).to eq([["duplicate of row 2: employee E1 already has a salary starting 2024-01-01 in this file"]])
  end

  it "accepts the same employee with a later effective date (salary history)" do
    batch = stage([import_row, import_row("effective_from" => "2025-01-01", "base_pay" => "1200", "gross" => "1200", "net" => "1050")])
    expect(batch.accepted_rows).to eq(2)
  end

  it "rejects a row that clashes with a salary already in the system" do
    create(:salary_record, employee: create(:employee, employee_number: "E1", name: "Asha Rao"), effective_from: Date.new(2024, 1, 1))
    expect(rejected_reasons(stage([import_row]))).to eq([["a salary for employee E1 starting 2024-01-01 already exists in the system"]])
  end

  it "rejects a different name for an employee number already in the system" do
    create(:employee, employee_number: "E1", name: "Someone Else")
    expect(rejected_reasons(stage([import_row])).first.first).to include("already exists in the system under the name 'Someone Else'")
  end

  it "rejects a different name for the same employee number within the file" do
    batch = stage([import_row, import_row("name" => "Other Person", "effective_from" => "2025-01-01")])
    expect(rejected_reasons(batch).first.first).to include("different name than in row 2")
  end

  it "refuses the same file a second time" do
    path = csv_path([import_row])
    described_class.call(path:, filename: "a.csv", uploaded_by: "hr@acme.test")

    expect { described_class.call(path:, filename: "again.csv", uploaded_by: "hr@acme.test") }
      .to raise_error(AppErrors::Conflict, /already uploaded/)
    expect(ImportBatch.count).to eq(1)
  end

  it "refuses a file with missing columns" do
    expect { stage([import_row], headers: %w[employee_number name]) }.to raise_error(AppErrors::BadRequest, /missing columns: country/)
  end

  it "audits the upload" do
    stage([import_row])
    expect(AuditEvent.find_by!(action: "import.staged").details).to include("total_rows" => 1, "accepted_rows" => 1)
  end
end
