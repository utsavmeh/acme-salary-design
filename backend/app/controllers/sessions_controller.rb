# Sign in with username and password; returns a session token for the Authorization header.
class SessionsController < ApplicationController
  skip_before_action :authenticate!, :require_password_changed!

  def create
    user = Auth::Login.call(username: params[:username], password: params[:password], ip: request.remote_ip)
    render json: { token: Auth::Tokens.issue(user), user: MePresenter.call(user) }, status: :created
  end
end
