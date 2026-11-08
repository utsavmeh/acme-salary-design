class ReportsController < ApplicationController
  REPORTS = {
    "pay_summary" => Reports::PaySummary,
    "top_paid" => Reports::TopPaid,
    "hikes" => Reports::Hikes,
    "data_quality" => Reports::DataQuality
  }.freeze
  PARAMS = %i[as_of currency_mode group_by department job_title country limit year sort_by].freeze

  before_action { require_role!(:hr) }

  def show
    report_class = REPORTS.fetch(params[:name]) { raise ActiveRecord::RecordNotFound, "Unknown report #{params[:name]}" }
    filters = params.permit(*PARAMS).to_h
    result = report_class.new(filters).call

    AuditLog.record(actor:, action: "report.viewed", details: { report: params[:name], parameters: filters })
    render json: result
  end
end
