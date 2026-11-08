require "rails_helper"

RSpec.describe "Audit events API" do
  before do
    AuditLog.record(actor: "hr@acme.test", action: "employee.viewed")
    AuditLog.record(actor: "other@acme.test", action: "report.viewed")
  end

  it "is readable by auditors, newest first" do
    get "/api/audit_events", headers: auditor_headers

    expect(response).to have_http_status(:ok)
    actions = response.parsed_body["data"].map { |e| e["action"] }
    expect(actions).to eq(%w[roles.first_seen report.viewed employee.viewed])
  end

  it "is forbidden for HR managers and rate managers" do
    get "/api/audit_events", headers: hr_headers
    expect(response).to have_http_status(:forbidden)
    get "/api/audit_events", headers: rate_manager_headers
    expect(response).to have_http_status(:forbidden)
  end

  it "filters by actor and action" do
    get "/api/audit_events", params: { actor: "HR@acme.test", action_name: "employee.viewed" }, headers: auditor_headers
    expect(response.parsed_body["data"].map { |e| e["actor"] }).to eq([ "hr@acme.test" ])
  end

  it "records that the log was read" do
    get "/api/audit_events", headers: auditor_headers
    expect(AuditEvent.where(action: "audit.viewed", actor: "auditor@acme.test").count).to eq(1)
  end

  describe "GET /api/audit_events/verify" do
    it "reports an intact chain" do
      get "/api/audit_events/verify", headers: auditor_headers
      expect(response.parsed_body).to eq("valid" => true, "broken_at_id" => nil)
    end

    it "reports where the chain was broken" do
      victim = AuditEvent.find_by!(action: "employee.viewed")
      AuditEvent.where(id: victim.id).update_all(actor: "forged@acme.test")

      get "/api/audit_events/verify", headers: auditor_headers
      expect(response.parsed_body).to include("valid" => false, "broken_at_id" => victim.id)
    end
  end
end
