class MePresenter
  def self.call(user)
    { username: user.username, roles: user.roles, must_change_password: user.must_change_password }
  end
end
