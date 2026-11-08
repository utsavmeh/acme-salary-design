class EmployeePresenter
  # `current_salary` is the employee's salary record in force today, or nil.
  def self.call(employee, current_salary: nil, as_of: Date.current)
    assignment = employee.assignment_on(as_of)
    {
      id: employee.id, employee_number: employee.employee_number, name: employee.name,
      country: employee.country, hire_date: employee.hire_date, status: employee.status,
      department: assignment&.department, job_title: assignment&.job_title,
      current_salary: current_salary && SalaryRecordPresenter.call(current_salary)
    }
  end
end
