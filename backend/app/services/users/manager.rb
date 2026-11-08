require "securerandom"

module Users
  # Account management for the people who run the system (there is no admin screen in the app).
  # Used by the `users:*` rake tasks. Each action is audited under "cli:<operator>", so changes of
  # access are always attributable even though no one is signed in to the web app.
  class Manager
    Created = Struct.new(:user, :temporary_password)

    def initialize(operator:)
      @actor = "cli:#{operator}"
    end

    def create(username:, roles:)
      password = temporary_password
      user = User.transaction do
        created = User.create!(username:, roles: Array(roles), password:, must_change_password: true)
        audit("user.created", created, roles: created.roles)
        created
      end
      Created.new(user, password)
    end

    def set_roles(username, roles)
      user = find(username)
      before = user.roles
      User.transaction do
        user.update!(roles: Array(roles))
        audit("user.roles_changed", user, from: before, to: user.roles)
      end
      user
    end

    # Gives a new one-time password; the user must choose their own at the next sign-in.
    def reset_password(username)
      user = find(username)
      password = temporary_password
      User.transaction do
        user.update!(password:, must_change_password: true, failed_attempts: 0, locked_until: nil)
        audit("user.password_reset", user)
      end
      Created.new(user, password)
    end

    def deactivate(username) = change_status(username, "deactivated", "user.deactivated")
    def activate(username) = change_status(username, "active", "user.activated")

    def unlock(username)
      user = find(username)
      User.transaction do
        user.update!(failed_attempts: 0, locked_until: nil)
        audit("user.unlocked", user)
      end
      user
    end

    def list = User.order(:username)

    private

    def find(username)
      User.find_by(username: username.to_s.strip.downcase) or raise AppErrors::BadRequest, "No user named '#{username}'"
    end

    def change_status(username, status, action)
      user = find(username)
      return user if user.status == status

      User.transaction do
        user.update!(status:, failed_attempts: 0, locked_until: nil)
        audit(action, user)
      end
      user
    end

    def temporary_password = SecureRandom.alphanumeric(20)

    def audit(action, user, **details)
      AuditLog.record(actor: @actor, action:, target: user, details:)
    end
  end
end
