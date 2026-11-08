module Reports
  # What is missing from the data, so gaps are visible instead of silently distorting reports:
  # active employees without a salary record, employees without a department, and the
  # (currency, year) pairs that have pay but no exchange rate.
  class DataQuality < Base
    def initialize(params = {}, **options)
      super(params.to_h.merge(currency_mode: "usd"), **options)
    end

    def call
      rows = current_rows
      rows.each { |r| conversion.convert(r.record.base_pay, r.record.currency, as_of.year) }
      with_pay = rows.map { |r| r.employee.id }

      envelope(
        employees_without_salary: Employee.where(status: "active").where.not(id: with_pay).order(:employee_number)
                                          .map { |e| { employee_id: e.id, employee_number: e.employee_number, name: e.name } },
        employees_without_department: rows.select { |r| r.assignment.nil? }.map { |r| person(r.employee, nil).slice(:employee_id, :employee_number, :name) }
      )
    end
  end
end
