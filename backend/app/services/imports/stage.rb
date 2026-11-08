require "digest"

module Imports
  # Step 1 of the migration: read the file, check every row, and store the result. Nothing is
  # written to employees or salaries yet. A row is rejected for its own problems (RowValidator) and
  # for problems with the rest of the data: a repeat inside the file, a clash with data already in the
  # system, or a different name for the same employee number.
  class Stage
    def self.call(path:, filename:, uploaded_by:) = new(path, filename, uploaded_by).call

    def initialize(path, filename, uploaded_by)
      @path = path
      @filename = filename
      @uploaded_by = uploaded_by
    end

    def call
      sha = Digest::SHA256.file(@path).hexdigest
      if (earlier = ImportBatch.find_by(file_sha256: sha))
        raise AppErrors::Conflict, "This exact file was already uploaded (import ##{earlier.id}). Fix the rejected rows in a new file and upload that."
      end

      rows = Parser.call(@path, @filename)
      require_columns!(rows)
      checker = ContextChecker.new(rows)

      ImportBatch.transaction do
        batch = ImportBatch.create!(filename: @filename, file_sha256: sha, uploaded_by: @uploaded_by, total_rows: rows.size)
        staged = rows.map { |row| stage_row(batch, row, checker) }
        ImportRow.insert_all!(staged)
        accepted = staged.count { |r| r[:status] == "accepted" }
        batch.update!(accepted_rows: accepted, rejected_rows: staged.size - accepted)
        AuditLog.record(actor: @uploaded_by, action: "import.staged", target: batch,
                        details: { filename: @filename, total_rows: batch.total_rows, accepted_rows: accepted, rejected_rows: batch.rejected_rows })
        batch
      end
    rescue ActiveRecord::RecordNotUnique
      raise AppErrors::Conflict, "This exact file was just uploaded by someone else."
    end

    private

    def require_columns!(rows)
      return if rows.empty?

      missing = RowValidator::REQUIRED - rows.first.values.keys
      raise AppErrors::BadRequest, "The file is missing columns: #{missing.join(', ')}" if missing.any?
    end

    def stage_row(batch, row, checker)
      result = RowValidator.call(row.values)
      reasons = result.reasons + (result.data ? checker.problems_for(row.number, result.data) : [])
      {
        import_batch_id: batch.id, row_number: row.number, raw: row.values,
        status: reasons.empty? ? "accepted" : "rejected",
        data: reasons.empty? ? JSON.parse(result.data.to_json) : nil, reasons:
      }
    end

    # Checks that need to look beyond a single row. Rows are visited in file order, so the
    # first occurrence wins and later repeats are the ones rejected.
    class ContextChecker
      def initialize(rows)
        numbers = rows.map { |r| r.values["employee_number"].to_s.strip }.uniq
        @employees = Employee.where(employee_number: numbers).index_by(&:employee_number)
        @existing_dates = SalaryRecord.joins(:employee).where(employees: { employee_number: numbers })
                                      .pluck("employees.employee_number", :effective_from).to_set
        @first_row_for_pay = {}
        @first_row_for_person = {}
      end

      def problems_for(row_number, data)
        [ name_problem(row_number, data), pay_problem(row_number, data) ].compact
      end

      private

      def name_problem(row_number, data)
        number = data[:employee_number]
        known_name = @employees[number]&.name
        if known_name && known_name.casecmp?(data[:name]) == false
          return "employee #{number} already exists in the system under the name '#{known_name}', not '#{data[:name]}'"
        end

        earlier = @first_row_for_person[number]
        return "employee #{number} has a different name than in row #{earlier[:row]} ('#{earlier[:name]}')" if earlier && !earlier[:name].casecmp?(data[:name])

        @first_row_for_person[number] ||= { row: row_number, name: data[:name] }
        nil
      end

      def pay_problem(row_number, data)
        key = [ data[:employee_number], data[:effective_from] ]
        return "a salary for employee #{key[0]} starting #{key[1]} already exists in the system" if @existing_dates.include?(key)

        if (first = @first_row_for_pay[key])
          return "duplicate of row #{first}: employee #{key[0]} already has a salary starting #{key[1]} in this file"
        end

        @first_row_for_pay[key] = row_number
        nil
      end
    end
  end
end
