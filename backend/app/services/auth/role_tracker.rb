module Auth
  # Notices when someone's roles changed in the identity provider since their last request and
  # writes an audit event, so access changes made outside this app are still visible here.
  class RoleTracker
    def self.observe(identity)
      new(identity).observe
    end

    def initialize(identity)
      @identity = identity
    end

    def observe
      current = @identity.roles.map(&:to_s).sort
      previous = RoleSnapshot.latest_for(@identity.email)
      return if previous && previous.roles.sort == current

      RoleSnapshot.transaction do
        RoleSnapshot.create!(email: @identity.email, roles: current, seen_at: Time.current)
        AuditLog.record(
          actor: @identity.email,
          action: previous ? "roles.changed" : "roles.first_seen",
          details: { from: previous&.roles, to: current }
        )
      end
    end
  end
end
