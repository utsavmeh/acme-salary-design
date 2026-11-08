class EmployeesController < ApplicationController
  PER_PAGE_MAX = 100

  before_action { require_role!(:hr) }

  def index
    search = EmployeeSearch.new(params.permit(*EmployeeSearch::FILTERS))
    scope = search.call
    page = [ params.fetch(:page, 1).to_i, 1 ].max
    per_page = params.fetch(:per_page, 25).to_i.clamp(1, PER_PAGE_MAX)
    total = scope.count
    employees = scope.includes(:assignments).offset((page - 1) * per_page).limit(per_page).to_a

    AuditLog.record(actor:, action: "employees.searched", details: { filters: search.applied_filters, page:, per_page:, result_count: employees.size })
    render json: { data: present(employees), page:, per_page:, total: }
  end

  def show
    employee = Employee.includes(:assignments).find(params[:id])
    AuditLog.record(actor:, action: "employee.viewed", target: employee)
    render json: EmployeePresenter.call(employee, current_salary: current_salaries_for([ employee.id ])[employee.id])
  end

  def create
    employee = nil
    Employee.transaction do
      employee = Employee.create!(employee_params)
      AuditLog.record(actor:, action: "employee.created", target: employee, details: { employee_number: employee.employee_number })
    end
    render json: EmployeePresenter.call(employee), status: :created
  end

  def update
    employee = Employee.find(params[:id])
    Employee.transaction do
      employee.assign_attributes(employee_params.except(:employee_number))
      changes = employee.changes.except("updated_at")
      employee.save!
      AuditLog.record(actor:, action: "employee.updated", target: employee, details: { changes: })
    end
    render json: EmployeePresenter.call(employee)
  end

  private

  def employee_params
    params.require(:employee).permit(:employee_number, :name, :country, :hire_date, :status)
  end

  def present(employees)
    salaries = current_salaries_for(employees.map(&:id))
    employees.map { |e| EmployeePresenter.call(e, current_salary: salaries[e.id]) }
  end

  def current_salaries_for(ids) = SalaryRecord.current_by_employee(ids)
end
