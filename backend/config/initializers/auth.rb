# The company sign-in system issues a signed token (JWT) with the user's email and groups.
# This app only verifies it; it stores no passwords. In production JWT_SECRET must be set
# to the key shared with the sign-in system.
Rails.configuration.x.auth.jwt_secret =
  ENV.fetch("JWT_SECRET") do
    raise "JWT_SECRET must be set in production" if Rails.env.production?

    "development-only-secret-do-not-use-in-production"
  end
