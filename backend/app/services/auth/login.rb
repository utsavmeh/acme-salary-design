require "bcrypt"

module Auth
  # Checks a username and password. Every outcome is audited. The caller always gets the same
  # message for every kind of failure (unknown user, wrong password, locked, deactivated), so
  # the answer does not reveal which usernames exist.
  class Login
    MESSAGE = "Invalid username or password. After repeated failures the account is locked for 15 minutes.".freeze
    # Compared against when the username is unknown, so that case takes as long as a real check.
    DUMMY_DIGEST = BCrypt::Password.create("not-a-real-password", cost: BCrypt::Engine.cost)

    def self.call(username:, password:, ip: nil) = new(username, password, ip).call

    def initialize(username, password, ip)
      @name = username.to_s.strip.downcase[0, 64]
      @password = password.to_s
      @ip = ip
    end

    def call
      result = User.transaction { authenticate(User.find_by(username: @name)) }
      raise AppErrors::Unauthorized, MESSAGE unless result.is_a?(User)

      result
    end

    private

    def authenticate(user)
      return fail_unknown if user.nil?
      return fail_with("login.blocked", user, reason: "deactivated") unless user.active?
      return fail_with("login.blocked", user, reason: "locked") if user.locked?

      if user.authenticate(@password)
        user.record_successful_login!
        audit("login.succeeded", user)
        user
      else
        locked = user.record_failed_login!
        fail_with(locked ? "login.locked" : "login.failed", user, reason: "wrong_password")
      end
    end

    def fail_unknown
      BCrypt::Password.new(DUMMY_DIGEST).is_password?(@password)
      audit("login.failed", nil, reason: "unknown_user")
      :failed
    end

    def fail_with(action, user, reason:)
      audit(action, user, reason:)
      :failed
    end

    def audit(action, user, reason: nil)
      AuditLog.record(actor: user&.username || @name.presence || "(blank)", action:, target: user, details: { ip: @ip, reason: }.compact)
    end
  end
end
