class ApplicationController < ActionController::API
  before_action :authenticate!
  before_action :require_password_changed!

  rescue_from AppErrors::Unauthorized do |e| render_error(:unauthorized, e.message) end
  rescue_from AppErrors::Forbidden do |e| render_error(:forbidden, e.message) end
  rescue_from AppErrors::PasswordChangeRequired do |e|
    render json: { error: e.message, code: "password_change_required" }, status: :forbidden
  end
  rescue_from AppErrors::Conflict do |e| render_error(:conflict, e.message) end
  rescue_from AppErrors::BadRequest do |e| render_error(:unprocessable_content, e.message) end
  rescue_from ActiveRecord::RecordNotFound do |e| render_error(:not_found, e.message) end
  rescue_from ActionController::ParameterMissing do |e| render_error(:bad_request, e.message) end
  rescue_from ActiveRecord::RecordInvalid do |e|
    render json: { error: "Validation failed", details: e.record.errors.to_hash }, status: :unprocessable_content
  end

  private

  attr_reader :current_user

  def authenticate!
    token = request.authorization.to_s[/\ABearer (.+)\z/, 1]
    raise AppErrors::Unauthorized, "Missing bearer token" unless token

    @current_user = Auth::Tokens.verify(token)
  end

  # A new or reset account may do nothing except choose its own password.
  def require_password_changed!
    raise AppErrors::PasswordChangeRequired, "Choose a new password before continuing" if current_user.must_change_password
  end

  # Every endpoint states which roles may call it. A user with no role gets 403 everywhere.
  def require_role!(*roles)
    return if current_user.has_any_role?(*roles)

    raise AppErrors::Forbidden, "Your account is not allowed to do this"
  end

  def actor = current_user.username

  def render_error(status, message)
    render json: { error: message }, status:
  end
end
