# Downloads the employee list (with the same filters as the search) as CSV.
# Exports are the easiest way to take data out, so every one is audited with its row count.
class EmployeeExportsController < ApplicationController
  before_action { require_role!(:hr) }

  def show
    search = EmployeeSearch.new(params.permit(*EmployeeSearch::FILTERS))
    employees = search.call.includes(:assignments).to_a
    csv = EmployeeCsv.new(employees, SalaryRecord.current_by_employee(employees.map(&:id))).call

    AuditLog.record(actor:, action: "employees.exported", details: { filters: search.applied_filters, row_count: employees.size })
    send_data csv, type: "text/csv", filename: "employees-#{Date.current}.csv"
  end
end
