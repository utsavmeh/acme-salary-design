class SalaryRecordPresenter
  def self.call(record)
    {
      id: record.id, employee_id: record.employee_id, effective_from: record.effective_from,
      version: record.version, currency: record.currency, country: record.country,
      base_pay: MoneyFormat.call(record.base_pay), gross: MoneyFormat.call(record.gross),
      deductions: record.deduction_lines.map { |line| { label: line.label, amount: MoneyFormat.call(line.amount) } },
      net: MoneyFormat.call(record.net), created_by: record.created_by, created_at: record.created_at
    }
  end
end
