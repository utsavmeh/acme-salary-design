# Finds employees by name/number text and by country, status, and the department or job title
# they hold today. Filters combine with AND.
class EmployeeSearch
  FILTERS = %i[q country status department job_title].freeze

  def initialize(params, today: Date.current)
    @params = params.to_h.symbolize_keys.slice(*FILTERS).compact_blank
    @today = today
  end

  def call
    scope = Employee.order(:name, :id)
    scope = scope.where("employees.name ILIKE :q OR employees.employee_number ILIKE :q", q: "%#{Employee.sanitize_sql_like(@params[:q])}%") if @params[:q]
    scope = scope.where(country: @params[:country].to_s.upcase) if @params[:country]
    scope = scope.where(status: @params[:status]) if @params[:status]
    scope = scope.where(id: current_assignments.select(:employee_id)) if @params[:department] || @params[:job_title]
    scope
  end

  # The filters that were actually applied (for the audit log).
  def applied_filters = @params

  private

  def current_assignments
    scope = Assignment.where(<<~SQL.squish, @today)
      assignments.effective_from = (
        SELECT MAX(a.effective_from) FROM assignments a
        WHERE a.employee_id = assignments.employee_id AND a.effective_from <= ?
      )
    SQL
    scope = scope.where(department: @params[:department]) if @params[:department]
    scope = scope.where(job_title: @params[:job_title]) if @params[:job_title]
    scope
  end
end
