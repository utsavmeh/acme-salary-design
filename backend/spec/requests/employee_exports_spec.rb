require "rails_helper"
require "csv"

RSpec.describe "GET /api/employees/export" do
  before do
    asha = employee_in("Engineering", number: "E1", country: "IN")
    pay(asha, 1000)
    employee_in("Sales", number: "E2", country: "US")
    evil = create(:employee, employee_number: "E3", name: "=HYPERLINK(\"http://evil\")", country: "US")
    create(:assignment, employee: evil)
  end

  def export(params = {})
    get "/api/employees/export", params:, headers: hr_headers
    CSV.parse(response.body, headers: true)
  end

  it "returns a CSV with pay and department" do
    table = export(country: "IN")

    expect(response.media_type).to eq("text/csv")
    expect(table.size).to eq(1)
    expect(table.first.to_h).to include("employee_number" => "E1", "department" => "Engineering", "currency" => "INR", "base_pay" => "1000.00", "net" => "850.00")
  end

  it "applies the same filters as the search" do
    expect(export(department: "Sales").map { |r| r["employee_number"] }).to eq(["E2"])
  end

  it "neutralises formulas in text cells" do
    expect(export.find { |r| r["employee_number"] == "E3" }["name"]).to start_with("'=")
  end

  it "audits the export with the number of rows" do
    export(country: "US")
    expect(AuditEvent.find_by!(action: "employees.exported").details).to include("row_count" => 2, "filters" => { "country" => "US" })
  end

  it "is only for HR" do
    get "/api/employees/export", headers: auditor_headers
    expect(response).to have_http_status(:forbidden)
  end
end
