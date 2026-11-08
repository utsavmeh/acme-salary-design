require "rails_helper"

RSpec.describe "GET /api/me" do
  it "returns the email and roles of the signed-in user" do
    get "/api/me", headers: auth_headers(email: "Jo@acme.test", groups: %w[salary-hr salary-auditor])

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("email" => "jo@acme.test", "roles" => %w[auditor hr])
  end

  it "answers 401 without a token" do
    get "/api/me"
    expect(response).to have_http_status(:unauthorized)
  end

  it "answers 401 for a token signed with the wrong key" do
    get "/api/me", headers: auth_headers(secret: "wrong")
    expect(response).to have_http_status(:unauthorized)
  end

  it "records a first-seen audit event, and an access change on the next visit" do
    get "/api/me", headers: auth_headers(email: "jo@acme.test", groups: ["salary-hr"])
    get "/api/me", headers: auth_headers(email: "jo@acme.test", groups: %w[salary-hr salary-rate-manager])

    expect(AuditEvent.order(:id).pluck(:action)).to eq(%w[roles.first_seen roles.changed])
  end
end
