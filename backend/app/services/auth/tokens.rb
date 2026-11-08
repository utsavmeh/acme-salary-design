require "digest"
require "jwt"

module Auth
  # Session tokens. A token holds only the user's id; the user's status and roles are read from
  # the database on every request, so deactivating someone or changing their roles takes effect
  # immediately. A token also carries a fingerprint of the password, so changing or resetting the
  # password signs out every existing session.
  module Tokens
    ALGORITHM = "HS256".freeze
    LIFETIME = 8.hours

    module_function

    def issue(user, now: Time.current)
      payload = { sub: user.id, pwd: fingerprint(user), iat: now.to_i, exp: (now + LIFETIME).to_i }
      JWT.encode(payload, secret, ALGORITHM)
    end

    def verify(token)
      payload, = JWT.decode(token.to_s, secret, true, algorithm: ALGORITHM, verify_expiration: true, required_claims: %w[exp sub pwd])
      user = User.find_by(id: payload["sub"])
      raise AppErrors::Unauthorized, "Please sign in again" unless user&.active? && payload["pwd"] == fingerprint(user)

      user
    rescue JWT::DecodeError
      raise AppErrors::Unauthorized, "Please sign in again"
    end

    def secret = Rails.configuration.x.auth.jwt_secret

    def fingerprint(user) = Digest::SHA256.hexdigest(user.password_digest)[0, 16]
  end
end
