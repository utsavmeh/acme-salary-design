require "rails_helper"

RSpec.describe "Reports API" do
  before do
    travel_to Time.zone.local(2025, 6, 30, 12)
    rate("INR", 2025, "0.01")
    pay(employee_in("Engineering", number: "E1"), 1000)
  end

  after { travel_back }

  it "returns a report and audits who ran it with which parameters" do
    get "/api/reports/pay_summary", params: { group_by: "country" }, headers: hr_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["groups"].first).to include("group" => "IN", "total" => "10.00")
    event = AuditEvent.find_by!(action: "report.viewed")
    expect(event.details).to eq("report" => "pay_summary", "parameters" => { "group_by" => "country" })
  end

  it "answers 422 with a clear message for a native report across currencies" do
    pay(employee_in("Sales", number: "E2", country: "US"), 1000, currency: "USD")
    get "/api/reports/pay_summary", params: { currency_mode: "native" }, headers: hr_headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to include("single currency")
  end

  it "answers 404 for an unknown report" do
    get "/api/reports/secrets", headers: hr_headers
    expect(response).to have_http_status(:not_found)
  end

  it "is only for HR" do
    get "/api/reports/pay_summary", headers: auditor_headers
    expect(response).to have_http_status(:forbidden)
  end
end
