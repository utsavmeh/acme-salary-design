module Imports
  # Step 2: load all accepted rows for real, in ONE transaction. Either every accepted row is
  # loaded or none is. If anything has changed since staging (for example someone added the same
  # salary by hand) the commit stops with a message and nothing is saved.
  class Commit
    def self.call(batch:, actor:, confirm_rejected: false) = new(batch, actor, confirm_rejected).call

    def initialize(batch, actor, confirm_rejected)
      @batch = batch
      @actor = actor
      @confirm_rejected = confirm_rejected
    end

    def call
      ImportBatch.transaction do
        @batch.lock!
        raise AppErrors::Conflict, "Import ##{@batch.id} was already committed" if @batch.committed?
        if @batch.rejected_rows.positive? && !@confirm_rejected
          raise AppErrors::BadRequest, "#{@batch.rejected_rows} rows were rejected and will NOT be loaded. Review them, then confirm with confirm_rejected_rows=true."
        end

        @batch.import_rows.accepted.order(:row_number).each { |row| load_row(row) }
        @batch.update!(status: "committed", committed_by: @actor, committed_at: Time.current)
        AuditLog.record(actor: @actor, action: "import.committed", target: @batch,
                        details: { loaded_rows: @batch.accepted_rows, rejected_rows: @batch.rejected_rows })
        @batch
      end
    rescue ActiveRecord::RecordNotUnique
      raise AppErrors::Conflict, "Data changed while committing. Nothing was loaded; stage the file again."
    end

    private

    def load_row(row)
      data = row.data.symbolize_keys
      employee = Employee.find_or_create_by!(employee_number: data[:employee_number]) do |e|
        e.assign_attributes(name: data[:name], country: data[:country], hire_date: data[:hire_date])
      end
      add_assignment(employee, data)
      add_salary(employee, data, row)
    end

    def add_assignment(employee, data)
      current = employee.assignments.where("effective_from <= ?", data[:effective_from]).order(:effective_from).last
      return if current && current.department == data[:department] && current.job_title == data[:job_title]
      return if employee.assignments.exists?(effective_from: data[:effective_from])

      employee.assignments.create!(department: data[:department], job_title: data[:job_title], effective_from: data[:effective_from])
    end

    def add_salary(employee, data, row)
      if employee.salary_records.exists?(effective_from: data[:effective_from])
        raise AppErrors::Conflict, "Row #{row.row_number}: a salary for #{employee.employee_number} starting #{data[:effective_from]} now exists. Nothing was loaded."
      end

      record = employee.salary_records.build(
        currency: data[:currency], country: data[:country], base_pay: data[:base_pay], gross: data[:gross], net: data[:net],
        effective_from: data[:effective_from], version: 1, created_by: @actor, import_batch: @batch
      )
      data[:deductions].each { |d| record.deduction_lines.build(label: d["label"], amount: d["amount"]) }
      record.save!
    end
  end
end
