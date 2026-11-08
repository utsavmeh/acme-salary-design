class ApplicationController < ActionController::API
  before_action :authenticate!

  rescue_from AppErrors::Unauthorized do |e| render_error(:unauthorized, e.message) end
  rescue_from AppErrors::Forbidden do |e| render_error(:forbidden, e.message) end
  rescue_from AppErrors::Conflict do |e| render_error(:conflict, e.message) end
  rescue_from AppErrors::BadRequest do |e| render_error(:unprocessable_entity, e.message) end
  rescue_from ActiveRecord::RecordNotFound do |e| render_error(:not_found, e.message) end
  rescue_from ActionController::ParameterMissing do |e| render_error(:bad_request, e.message) end
  rescue_from ActiveRecord::RecordInvalid do |e|
    render json: { error: "Validation failed", details: e.record.errors.to_hash }, status: :unprocessable_entity
  end

  private

  attr_reader :current_identity

  def authenticate!
    token = request.authorization.to_s[/\ABearer (.+)\z/, 1]
    raise AppErrors::Unauthorized, "Missing bearer token" unless token

    @current_identity = Auth::TokenVerifier.new.verify(token)
    Auth::RoleTracker.observe(@current_identity)
  end

  # Every endpoint states which roles may call it. A person with no salary role gets 403 everywhere.
  def require_role!(*roles)
    return if current_identity.has_any_role?(*roles)

    raise AppErrors::Forbidden, "Your account is not allowed to do this"
  end

  def actor = current_identity.email

  def render_error(status, message)
    render json: { error: message }, status:
  end
end
