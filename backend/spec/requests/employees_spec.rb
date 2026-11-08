require "rails_helper"

RSpec.describe "Employees API" do
  let(:valid_params) do
    { employee: { employee_number: "E1", name: "Asha Rao", country: "IN", hire_date: "2021-04-01" } }
  end

  describe "access control" do
    it "answers 401 without a token" do
      get "/api/employees"
      expect(response).to have_http_status(:unauthorized)
    end

    it "answers 403 to a user with no salary role" do
      get "/api/employees", headers: auth_headers(groups: ["some-other-group"])
      expect(response).to have_http_status(:forbidden)
    end

    it "answers 403 to rate managers and auditors, who may not see employee pay" do
      get "/api/employees", headers: rate_manager_headers
      expect(response).to have_http_status(:forbidden)
      get "/api/employees", headers: auditor_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/employees" do
    let!(:asha) { create(:employee, name: "Asha Rao") }
    let!(:ben) { create(:employee, name: "Ben Smith", country: "US") }

    before do
      create(:assignment, employee: asha, department: "Engineering")
      create(:salary_record, employee: asha)
    end

    it "lists employees with department and current salary" do
      get "/api/employees", headers: hr_headers

      row = response.parsed_body["data"].first
      expect(row).to include("name" => "Asha Rao", "department" => "Engineering")
      expect(row["current_salary"]).to include("currency" => "INR", "base_pay" => "1000.00", "net" => "850.00")
      expect(response.parsed_body).to include("page" => 1, "total" => 2)
    end

    it "filters and paginates" do
      get "/api/employees", params: { country: "US", per_page: 1 }, headers: hr_headers
      expect(response.parsed_body["data"].map { |e| e["name"] }).to eq(["Ben Smith"])
    end

    it "caps the page size" do
      get "/api/employees", params: { per_page: 5000 }, headers: hr_headers
      expect(response.parsed_body["per_page"]).to eq(100)
    end

    it "audits the search with its filters and result count" do
      get "/api/employees", params: { country: "US" }, headers: hr_headers

      event = AuditEvent.find_by!(action: "employees.searched")
      expect(event.actor).to eq("hr@acme.test")
      expect(event.details).to include("filters" => { "country" => "US" }, "result_count" => 1)
    end
  end

  describe "GET /api/employees/:id" do
    it "returns the employee and audits the view" do
      employee = create(:employee)
      get "/api/employees/#{employee.id}", headers: hr_headers

      expect(response).to have_http_status(:ok)
      expect(AuditEvent.find_by!(action: "employee.viewed")).to have_attributes(target_id: employee.id.to_s)
    end

    it "answers 404 for an unknown employee" do
      get "/api/employees/0", headers: hr_headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/employees" do
    it "creates the employee and audits it" do
      post "/api/employees", params: valid_params, headers: hr_headers

      expect(response).to have_http_status(:created)
      expect(Employee.find_by!(employee_number: "E1").name).to eq("Asha Rao")
      expect(AuditEvent.pluck(:action)).to include("employee.created")
    end

    it "answers 422 with the reasons for invalid data and does not audit it" do
      post "/api/employees", params: { employee: valid_params[:employee].merge(country: "india") }, headers: hr_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["details"]).to have_key("country")
      expect(AuditEvent.where(action: "employee.created")).to be_empty
    end
  end

  describe "PATCH /api/employees/:id" do
    it "updates allowed fields, ignores the employee number, and audits the change" do
      employee = create(:employee, employee_number: "E1", name: "Old", status: "active")
      patch "/api/employees/#{employee.id}", params: { employee: { name: "New", status: "inactive", employee_number: "HACK" } }, headers: hr_headers

      expect(employee.reload).to have_attributes(name: "New", status: "inactive", employee_number: "E1")
      expect(AuditEvent.find_by!(action: "employee.updated").details["changes"]).to include("name" => %w[Old New])
    end
  end

  describe "POST /api/employees/:id/assignments" do
    let(:employee) { create(:employee) }
    let(:params) { { assignment: { department: "Sales", job_title: "Manager", effective_from: "2024-01-01" } } }

    it "adds a department/title from a date" do
      post "/api/employees/#{employee.id}/assignments", params:, headers: hr_headers
      expect(response).to have_http_status(:created)
      expect(employee.assignments.count).to eq(1)
    end

    it "answers 422 when an assignment already starts that day" do
      create(:assignment, employee:, effective_from: Date.new(2024, 1, 1))
      post "/api/employees/#{employee.id}/assignments", params:, headers: hr_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
