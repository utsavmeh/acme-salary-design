require "jwt"

module Auth
  # Checks the signature and expiry of a bearer token and turns its claims into an Identity.
  class TokenVerifier
    ALGORITHM = "HS256".freeze

    def initialize(secret: Rails.configuration.x.auth.jwt_secret)
      @secret = secret
    end

    def verify(token)
      payload, = JWT.decode(token.to_s, @secret, true, algorithm: ALGORITHM, verify_expiration: true, required_claims: %w[exp])
      email = payload["email"].to_s.strip.downcase
      raise AppErrors::Unauthorized, "Token has no email" if email.empty?

      Identity.new(email:, roles: Roles.from_groups(payload["groups"]))
    rescue JWT::DecodeError => e
      raise AppErrors::Unauthorized, "Invalid token: #{e.message}"
    end
  end
end
