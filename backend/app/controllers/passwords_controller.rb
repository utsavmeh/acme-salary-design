# Lets a signed-in user choose a new password. This is also the only thing a user with a
# temporary password may do. Changing the password signs out all other sessions.
class PasswordsController < ApplicationController
  skip_before_action :require_password_changed!

  def update
    unless current_user.authenticate(params.require(:current_password).to_s)
      current_user.record_failed_login!
      AuditLog.record(actor:, action: "password.change_failed", target: current_user)
      raise AppErrors::BadRequest, "The current password is incorrect"
    end

    new_password = params.require(:new_password).to_s
    raise AppErrors::BadRequest, "The new password must be different from the current one" if new_password == params[:current_password]

    User.transaction do
      current_user.update!(password: new_password, must_change_password: false)
      AuditLog.record(actor:, action: "password.changed", target: current_user)
    end
    render json: { token: Auth::Tokens.issue(current_user), user: MePresenter.call(current_user) }
  end
end
