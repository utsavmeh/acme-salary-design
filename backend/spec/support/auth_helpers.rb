# Signed-in users for request specs: each helper returns the Authorization header for a real user record.
module AuthHelpers
  def user_with(username, roles)
    User.find_by(username:) || create(:user, username:, roles:)
  end

  def headers_for(user) = { "Authorization" => "Bearer #{Auth::Tokens.issue(user)}" }

  def hr_headers = headers_for(user_with("hr@acme.test", [ "hr" ]))
  def rate_manager_headers = headers_for(user_with("rates@acme.test", [ "rate_manager" ]))
  def auditor_headers = headers_for(user_with("auditor@acme.test", [ "auditor" ]))
  def no_role_headers = headers_for(user_with("nobody@acme.test", []))
end

RSpec.configure { |config| config.include AuthHelpers }
