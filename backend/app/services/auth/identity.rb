module Auth
  # Who is calling: an email and the roles derived from their sign-in groups.
  Identity = Struct.new(:email, :roles, keyword_init: true) do
    def has_any_role?(*wanted) = (roles & wanted).any?
  end
end
