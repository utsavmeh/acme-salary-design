# One line of the audit log: who did what to what, and when. Append-only.
# Written through AuditLog.record, which links it to the previous event with a hash.
class AuditEvent < ApplicationRecord
  before_destroy { throw :abort }
  def readonly? = persisted? || super
end
