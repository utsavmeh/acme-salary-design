class ExchangeRatesController < ApplicationController
  # HR needs to read rates to understand reports; only rate managers may change them.
  before_action(only: :index) { require_role!(:hr, :rate_manager) }
  before_action(only: :create) { require_role!(:rate_manager) }

  # Latest version per currency and year. `all_versions=true` returns the full history.
  def index
    scope = ExchangeRate.order(:currency, year: :desc, version: :desc)
    scope = scope.latest_versions unless params[:all_versions] == "true"
    scope = scope.where(currency: params[:currency].to_s.upcase) if params[:currency].present?
    scope = scope.where(year: params[:year].to_i) if params[:year].present?
    render json: { data: scope.map { |rate| present(rate) } }
  end

  def create
    rate = nil
    ExchangeRate.transaction do
      previous = ExchangeRate.where(currency: rate_params[:currency], year: rate_params[:year]).order(:version).last
      rate = ExchangeRate.record!(**rate_params.to_h.symbolize_keys, set_by: actor)
      AuditLog.record(actor:, action: "exchange_rate.set", target: rate,
                      details: { currency: rate.currency, year: rate.year, version: rate.version, rate_to_usd: rate.rate_to_usd.to_s("F"),
                                 previous_rate_to_usd: previous&.rate_to_usd&.to_s("F"), reason: rate.reason })
    end
    render json: present(rate), status: :created
  end

  private

  def rate_params
    params.require(:exchange_rate).permit(:currency, :year, :rate_to_usd, :reason)
  end

  def present(rate)
    rate.slice(:id, :currency, :year, :version, :reason, :set_by, :created_at).merge(rate_to_usd: rate.rate_to_usd.to_s("F"))
  end
end
