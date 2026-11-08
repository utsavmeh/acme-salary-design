class MeController < ApplicationController
  skip_before_action :require_password_changed! # the sign-in screen needs this to know a change is due

  def show
    render json: MePresenter.call(current_user)
  end
end
