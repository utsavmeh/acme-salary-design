module Auth
  # Maps sign-in groups (managed by IT in the identity provider) to application roles.
  # There is deliberately no admin role: nobody can grant access from inside this app.
  module Roles
    GROUP_TO_ROLE = {
      "salary-hr" => :hr,                       # view and manage salary data, reports, imports
      "salary-rate-manager" => :rate_manager,   # set exchange rates
      "salary-auditor" => :auditor              # read the audit log
    }.freeze

    module_function

    def from_groups(groups)
      Array(groups).filter_map { |group| GROUP_TO_ROLE[group] }.uniq.sort
    end
  end
end
