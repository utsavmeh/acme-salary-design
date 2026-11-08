require "rails_helper"

RSpec.describe "Salary records API" do
  let(:employee) { create(:employee) }
  let(:payload) do
    { salary_record: { currency: "INR", base_pay: "1000", gross: "1000", net: "850", effective_from: "2024-01-01",
                       deductions: [{ label: "Income tax", amount: "150" }] } }
  end

  it "requires the hr role" do
    post "/api/employees/#{employee.id}/salary_records", params: payload, headers: rate_manager_headers
    expect(response).to have_http_status(:forbidden)
  end

  describe "POST /api/employees/:id/salary_records" do
    it "creates a record and returns it with its deductions" do
      post "/api/employees/#{employee.id}/salary_records", params: payload, headers: hr_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("currency" => "INR", "gross" => "1000.00", "net" => "850.00", "version" => 1)
      expect(response.parsed_body["deductions"]).to eq([{ "label" => "Income tax", "amount" => "150.00" }])
    end

    it "answers 422 when net does not match gross minus deductions" do
      payload[:salary_record][:net] = "900"
      post "/api/employees/#{employee.id}/salary_records", params: payload, headers: hr_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["details"]).to have_key("net")
    end

    it "answers 409 when the same request is sent twice (a retry)" do
      2.times { post "/api/employees/#{employee.id}/salary_records", params: payload, headers: hr_headers }

      expect(response).to have_http_status(:conflict)
      expect(employee.salary_records.count).to eq(1)
    end
  end

  describe "POST /api/salary_records/:id/correct" do
    let!(:record) { create(:salary_record, employee:) }

    it "creates version 2 and leaves version 1 in the history" do
      post "/api/salary_records/#{record.id}/correct", params: { salary_record: { base_pay: "1100", gross: "1100", net: "950" } }, headers: hr_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["version"]).to eq(2)
      expect(employee.salary_records.count).to eq(2)
    end

    it "answers 409 when correcting an already corrected version" do
      params = { salary_record: { base_pay: "1100", gross: "1100", net: "950" } }
      post "/api/salary_records/#{record.id}/correct", params:, headers: hr_headers
      post "/api/salary_records/#{record.id}/correct", params:, headers: hr_headers

      expect(response).to have_http_status(:conflict)
    end
  end

  describe "GET /api/employees/:id/salary_records" do
    before do
      create(:salary_record, employee:, effective_from: Date.new(2023, 1, 1))
      create(:salary_record, employee:, effective_from: Date.new(2024, 1, 1), version: 1)
      create(:salary_record, employee:, effective_from: Date.new(2024, 1, 1), version: 2, base_pay: 1100, gross: 1100, net: 950)
    end

    def history(**params)
      get "/api/employees/#{employee.id}/salary_records", params:, headers: hr_headers
      response.parsed_body["data"].map { |r| [r["effective_from"], r["version"]] }
    end

    it "lists the current versions, newest first" do
      expect(history).to eq([["2024-01-01", 2], ["2023-01-01", 1]])
    end

    it "can include superseded versions" do
      expect(history(all_versions: "true")).to eq([["2024-01-01", 2], ["2024-01-01", 1], ["2023-01-01", 1]])
    end

    it "audits the view" do
      history
      expect(AuditEvent.where(action: "salary_history.viewed").count).to eq(1)
    end
  end
end
