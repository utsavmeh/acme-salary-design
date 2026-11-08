class MeController < ApplicationController
  def show
    render json: { email: current_identity.email, roles: current_identity.roles }
  end
end
