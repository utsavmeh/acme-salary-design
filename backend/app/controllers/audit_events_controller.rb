# Read-only access to the audit log for the auditor group. Even HR managers cannot read it:
# it shows who looked at whose pay, so it must not be readable by the people it watches.
class AuditEventsController < ApplicationController
  PER_PAGE_MAX = 200

  before_action { require_role!(:auditor) }

  def index
    scope = AuditEvent.order(id: :desc)
    scope = scope.where(actor: params[:actor].to_s.downcase) if params[:actor].present?
    scope = scope.where(action: params[:action_name]) if params[:action_name].present?
    scope = scope.where(target_type: params[:target_type], target_id: params[:target_id]) if params[:target_type].present? && params[:target_id].present?
    scope = scope.where("occurred_at >= ?", Time.zone.parse(params[:from])) if params[:from].present?
    scope = scope.where("occurred_at <= ?", Time.zone.parse(params[:to])) if params[:to].present?

    page = [params.fetch(:page, 1).to_i, 1].max
    per_page = params.fetch(:per_page, 50).to_i.clamp(1, PER_PAGE_MAX)
    total = scope.count
    events = scope.offset((page - 1) * per_page).limit(per_page).to_a

    # Reading the log is itself recorded (after the read, so it does not appear in its own result).
    AuditLog.record(actor:, action: "audit.viewed", details: { result_count: events.size })
    render json: { data: events.map { |e| present(e) }, page:, per_page:, total: }
  end

  # Re-computes the hash chain to detect edited or deleted rows.
  def verify
    result = AuditLog.verify
    AuditLog.record(actor:, action: "audit.verified", details: { valid: result.valid })
    render json: { valid: result.valid, broken_at_id: result.broken_at_id }
  end

  private

  def present(event)
    event.slice(:id, :occurred_at, :actor, :action, :target_type, :target_id, :details)
  end
end
