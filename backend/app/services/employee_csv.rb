require "csv"

# Builds the CSV for the employee export: one row per employee with department and current pay.
class EmployeeCsv
  HEADERS = %w[employee_number name country status department job_title currency base_pay gross net effective_from].freeze

  def initialize(employees, salaries, as_of: Date.current)
    @employees = employees
    @salaries = salaries
    @as_of = as_of
  end

  def call
    CSV.generate do |csv|
      csv << HEADERS
      @employees.each { |employee| csv << row(employee) }
    end
  end

  private

  def row(employee)
    assignment = employee.assignment_on(@as_of)
    salary = @salaries[employee.id]
    [
      employee.employee_number, employee.name, employee.country, employee.status, assignment&.department, assignment&.job_title
    ].map { |text| CsvSanitizer.call(text) } + [
      salary&.currency, MoneyFormat.call(salary&.base_pay), MoneyFormat.call(salary&.gross), MoneyFormat.call(salary&.net), salary&.effective_from
    ]
  end
end
