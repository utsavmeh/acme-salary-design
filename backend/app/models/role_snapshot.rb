# The roles a person had the last time we saw them sign in. A new row is stored only when the
# roles differ from the previous row, which gives us a history of access changes made in the
# identity provider.
class RoleSnapshot < ApplicationRecord
  def self.latest_for(email) = where(email:).order(:seen_at, :id).last
end
