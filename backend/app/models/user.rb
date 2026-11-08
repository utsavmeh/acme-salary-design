# A person who can sign in. Users are never deleted, only deactivated, so the audit log
# always points at a real account. Accounts are managed from the command line (Users::Manager).
class User < ApplicationRecord
  ROLES = %w[hr rate_manager auditor].freeze
  STATUSES = %w[active deactivated].freeze
  MAX_FAILED_ATTEMPTS = 5
  LOCK_FOR = 15.minutes
  MIN_PASSWORD_LENGTH = 12

  has_secure_password

  before_validation { self.username = username.to_s.strip.downcase }

  validates :username, format: { with: /\A[a-z0-9][a-z0-9._@-]{2,63}\z/, message: "must be 3-64 characters: letters, digits and . _ @ -" },
                       uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validate :roles_are_known
  validate :password_is_strong, if: -> { password.present? }

  before_destroy { throw :abort }

  def active? = status == "active"
  def locked? = locked_until.present? && locked_until > Time.current
  def has_any_role?(*wanted) = (roles & wanted.map(&:to_s)).any?

  # Counts a wrong password. The count is updated in the database in one step so two parallel
  # guesses cannot both slip under the limit. Returns true when this failure locked the account.
  def record_failed_login!
    self.class.where(id:).update_all("failed_attempts = failed_attempts + 1")
    reload
    return false if failed_attempts < MAX_FAILED_ATTEMPTS

    update!(failed_attempts: 0, locked_until: LOCK_FOR.from_now)
    true
  end

  def record_successful_login!
    update!(failed_attempts: 0, locked_until: nil, last_login_at: Time.current)
  end

  private

  def roles_are_known
    unknown = roles - ROLES
    errors.add(:roles, "unknown: #{unknown.join(', ')}") if unknown.any?
  end

  def password_is_strong
    errors.add(:password, "must be at least #{MIN_PASSWORD_LENGTH} characters") if password.length < MIN_PASSWORD_LENGTH
    errors.add(:password, "must be at most 72 characters") if password.bytesize > 72
    errors.add(:password, "must not contain the username") if username.present? && password.downcase.include?(username)
  end
end
