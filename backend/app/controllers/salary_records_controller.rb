class SalaryRecordsController < ApplicationController
  before_action { require_role!(:hr) }

  # Salary history of one employee, newest first. `all_versions=true` also lists corrected-away versions.
  def index
    employee = Employee.find(params[:employee_id])
    scope = employee.salary_records.includes(:deduction_lines).order(effective_from: :desc, version: :desc)
    scope = scope.effective unless params[:all_versions] == "true"

    AuditLog.record(actor:, action: "salary_history.viewed", target: employee)
    render json: { data: scope.map { |r| SalaryRecordPresenter.call(r) } }
  end

  def create
    employee = Employee.find(params[:employee_id])
    record = SalaryRecordWriter.new(actor:).create(employee, record_params)
    render json: SalaryRecordPresenter.call(record), status: :created
  end

  def correct
    record = SalaryRecord.find(params[:id])
    corrected = SalaryRecordWriter.new(actor:).correct(record, record_params)
    render json: SalaryRecordPresenter.call(corrected), status: :created
  end

  private

  def record_params
    params.require(:salary_record).permit(:currency, :country, :base_pay, :gross, :net, :effective_from, deductions: %i[label amount])
  end
end
