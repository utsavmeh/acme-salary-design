# The app signs the session tokens it hands out at login. In production JWT_SECRET must be set
# to a long random value (for example `openssl rand -hex 64`); never reuse the development one.
Rails.configuration.x.auth.jwt_secret =
  ENV.fetch("JWT_SECRET") do
    raise "JWT_SECRET must be set in production" if Rails.env.production?

    "development-only-secret-do-not-use-in-production"
  end
