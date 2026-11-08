# Builds the Authorization header the real sign-in system would send.
module AuthHelpers
  def token_for(email: "hr@acme.test", groups: [ "salary-hr" ], exp: 1.hour.from_now.to_i, secret: Rails.configuration.x.auth.jwt_secret)
    JWT.encode({ email:, groups:, exp: }, secret, Auth::TokenVerifier::ALGORITHM)
  end

  def auth_headers(**options)
    { "Authorization" => "Bearer #{token_for(**options)}" }
  end

  def hr_headers = auth_headers(email: "hr@acme.test", groups: [ "salary-hr" ])
  def rate_manager_headers = auth_headers(email: "rates@acme.test", groups: [ "salary-rate-manager" ])
  def auditor_headers = auth_headers(email: "auditor@acme.test", groups: [ "salary-auditor" ])
end

RSpec.configure { |config| config.include AuthHelpers }
