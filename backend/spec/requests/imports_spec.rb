require "rails_helper"
require "csv"

RSpec.describe "Imports API" do
  let(:rows) { [ import_row, import_row("employee_number" => "E2", "net" => "1", "name" => "=cmd|' /C calc'!A0") ] }

  def upload(rows = self.rows, headers: hr_headers)
    post "/api/imports", params: { file: uploaded_csv(rows) }, headers: headers
    response.parsed_body
  end

  it "is only for HR" do
    post "/api/imports", params: { file: uploaded_csv(rows) }, headers: rate_manager_headers
    expect(response).to have_http_status(:forbidden)
  end

  describe "POST /api/imports" do
    it "stages the file and returns the counts" do
      body = upload

      expect(response).to have_http_status(:created)
      expect(body).to include("status" => "staged", "total_rows" => 2, "accepted_rows" => 1, "rejected_rows" => 1)
      expect(Employee.count).to eq(0)
    end

    it "answers 422 without a file" do
      post "/api/imports", headers: hr_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "answers 409 when the same file is uploaded twice" do
      path = csv_path(rows)
      2.times { post "/api/imports", params: { file: Rack::Test::UploadedFile.new(path, "text/csv") }, headers: hr_headers }
      expect(response).to have_http_status(:conflict)
    end
  end

  describe "rejected rows" do
    let!(:id) { upload["id"] }

    it "lists each rejected row with its line number and reasons" do
      get "/api/imports/#{id}/rejected_rows", headers: hr_headers

      row = response.parsed_body["data"].first
      expect(row).to include("row_number" => 3)
      expect(row["reasons"].first).to include("does not equal gross")
    end

    it "downloads them as CSV, protecting against formulas" do
      get "/api/imports/#{id}/rejected_rows.csv", headers: hr_headers

      table = CSV.parse(response.body, headers: true)
      expect(table.first.to_h).to include("row_number" => "3")
      expect(table.first["name"]).to start_with("'=")
    end
  end

  describe "reconciliation and commit" do
    let!(:id) { upload["id"] }

    it "reconciles before and after loading" do
      get "/api/imports/#{id}/reconciliation", headers: hr_headers
      expect(response.parsed_body).to include("balanced" => true, "loaded_matches_accepted" => nil)

      post "/api/imports/#{id}/commit", params: { confirm_rejected_rows: "true" }, headers: hr_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["status"]).to eq("committed")

      get "/api/imports/#{id}/reconciliation", headers: hr_headers
      expect(response.parsed_body).to include("loaded_matches_accepted" => true)
      expect(Employee.pluck(:employee_number)).to eq([ "E1" ])
    end

    it "refuses to commit while rejected rows are unconfirmed" do
      post "/api/imports/#{id}/commit", headers: hr_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(Employee.count).to eq(0)
    end

    it "answers 409 for a second commit" do
      2.times { post "/api/imports/#{id}/commit", params: { confirm_rejected_rows: "true" }, headers: hr_headers }
      expect(response).to have_http_status(:conflict)
    end
  end
end
