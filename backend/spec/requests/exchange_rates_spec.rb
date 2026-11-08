require "rails_helper"

RSpec.describe "Exchange rates API" do
  let(:payload) { { exchange_rate: { currency: "INR", year: 2024, rate_to_usd: "0.012", reason: "Annual rate" } } }

  describe "POST /api/exchange_rates" do
    it "lets a rate manager set a rate and audits it" do
      post "/api/exchange_rates", params: payload, headers: rate_manager_headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("currency" => "INR", "version" => 1, "set_by" => "rates@acme.test")
      expect(AuditEvent.find_by!(action: "exchange_rate.set").details).to include("rate_to_usd" => "0.012", "reason" => "Annual rate")
    end

    it "keeps the old rate when it is corrected, and audits old and new" do
      post "/api/exchange_rates", params: payload, headers: rate_manager_headers
      payload[:exchange_rate].merge!(rate_to_usd: "0.0125", reason: "Typo")
      post "/api/exchange_rates", params: payload, headers: rate_manager_headers

      expect(ExchangeRate.where(currency: "INR", year: 2024).pluck(:version)).to contain_exactly(1, 2)
      expect(AuditEvent.where(action: "exchange_rate.set").last.details).to include("previous_rate_to_usd" => "0.012", "rate_to_usd" => "0.0125")
    end

    it "is forbidden for HR managers, who cannot change rates" do
      post "/api/exchange_rates", params: payload, headers: hr_headers
      expect(response).to have_http_status(:forbidden)
      expect(ExchangeRate.count).to eq(0)
    end

    it "requires a reason" do
      payload[:exchange_rate][:reason] = ""
      post "/api/exchange_rates", params: payload, headers: rate_manager_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/exchange_rates" do
    before do
      create(:exchange_rate, version: 1, rate_to_usd: "0.012")
      create(:exchange_rate, version: 2, rate_to_usd: "0.0125")
      create(:exchange_rate, currency: "EUR", rate_to_usd: "1.08")
    end

    it "lists the latest version of each rate for HR" do
      get "/api/exchange_rates", headers: hr_headers

      rows = response.parsed_body["data"]
      expect(rows.map { |r| [ r["currency"], r["version"] ] }).to contain_exactly([ "EUR", 1 ], [ "INR", 2 ])
    end

    it "returns the full history on request, filtered by currency" do
      get "/api/exchange_rates", params: { all_versions: "true", currency: "inr" }, headers: hr_headers
      expect(response.parsed_body["data"].map { |r| r["version"] }).to eq([ 2, 1 ])
    end

    it "is not readable by auditors" do
      get "/api/exchange_rates", headers: auditor_headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
