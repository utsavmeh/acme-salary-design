require "rails_helper"

RSpec.describe "Sessions and password" do
  let!(:user) { create(:user, username: "asha", password: "correct horse battery", roles: [ "hr" ]) }

  def sign_in(password: "correct horse battery")
    post "/api/session", params: { username: "asha", password: }
  end

  describe "POST /api/session" do
    it "returns a token that opens the API" do
      sign_in

      expect(response).to have_http_status(:created)
      token = response.parsed_body["token"]
      expect(response.parsed_body["user"]).to eq("username" => "asha", "roles" => [ "hr" ], "must_change_password" => false)

      get "/api/employees", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)
    end

    it "answers 401 for a wrong password" do
      sign_in(password: "wrong")
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body).not_to have_key("token")
    end

    it "does not need a token to be called" do
      post "/api/session", params: { username: "nobody", password: "x" }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "access with a token" do
    it "answers 401 without a token or with a bad one" do
      get "/api/me"
      expect(response).to have_http_status(:unauthorized)
      get "/api/me", headers: { "Authorization" => "Bearer junk" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "answers 401 as soon as the user is deactivated" do
      token_headers = headers_for(user)
      user.update!(status: "deactivated")
      get "/api/me", headers: token_headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "answers 403 to a user with no role" do
      get "/api/employees", headers: no_role_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "temporary password" do
    before { user.update!(must_change_password: true) }

    it "blocks everything except reading /me and changing the password" do
      get "/api/employees", headers: headers_for(user)
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body["code"]).to eq("password_change_required")

      get "/api/me", headers: headers_for(user)
      expect(response.parsed_body["must_change_password"]).to be(true)
    end
  end

  describe "PATCH /api/me/password" do
    before { user.update!(must_change_password: true) }

    def change(current: "correct horse battery", new: "a much better passphrase")
      patch "/api/me/password", params: { current_password: current, new_password: new }, headers: headers_for(user)
    end

    it "sets the new password, lifts the restriction and returns a fresh token" do
      change

      expect(response).to have_http_status(:ok)
      expect(user.reload).to have_attributes(must_change_password: false)
      expect(user.authenticate("a much better passphrase")).to be_truthy
      get "/api/employees", headers: { "Authorization" => "Bearer #{response.parsed_body['token']}" }
      expect(response).to have_http_status(:ok)
      expect(AuditEvent.pluck(:action)).to include("password.changed")
    end

    it "signs out the old tokens" do
      old = headers_for(user)
      change
      get "/api/me", headers: old
      expect(response).to have_http_status(:unauthorized)
    end

    it "refuses a wrong current password and counts it towards the lockout" do
      change(current: "wrong")

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.failed_attempts).to eq(1)
      expect(AuditEvent.pluck(:action)).to include("password.change_failed")
    end

    it "refuses a weak or unchanged password" do
      change(new: "short")
      expect(response).to have_http_status(:unprocessable_content)
      change(new: "correct horse battery")
      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.must_change_password).to be(true)
    end
  end
end
