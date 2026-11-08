class AssignmentsController < ApplicationController
  before_action { require_role!(:hr) }

  def create
    employee = Employee.find(params[:employee_id])
    assignment = nil
    Assignment.transaction do
      assignment = employee.assignments.create!(params.require(:assignment).permit(:department, :job_title, :effective_from))
      AuditLog.record(actor:, action: "assignment.created", target: employee,
                      details: assignment.slice(:department, :job_title, :effective_from))
    end
    render json: assignment.slice(:id, :department, :job_title, :effective_from), status: :created
  rescue ActiveRecord::RecordNotUnique
    raise AppErrors::Conflict, "An assignment starting on that date already exists"
  end
end
