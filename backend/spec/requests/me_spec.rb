require "rails_helper"

RSpec.describe "GET /api/me" do
  it "returns the username and roles of the signed-in user" do
    user = create(:user, username: "jo.doe", roles: %w[hr auditor])
    get "/api/me", headers: headers_for(user)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("username" => "jo.doe", "roles" => %w[hr auditor], "must_change_password" => false)
  end

  it "answers 401 without a token" do
    get "/api/me"
    expect(response).to have_http_status(:unauthorized)
  end
end
