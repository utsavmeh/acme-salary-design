module Imports
  # Checks one row of text and returns clean typed values, or every reason it is not acceptable.
  # It is strict on purpose: a number with 3 decimals or a date like 03/04/2024 is rejected
  # rather than silently rounded or guessed.
  class RowValidator
    REQUIRED = %w[employee_number name country hire_date department job_title currency base_pay gross net effective_from].freeze
    AMOUNT = /\A\d+(\.\d{1,2})?\z/
    Result = Struct.new(:data, :reasons)

    def self.call(values) = new(values).call

    def initialize(values)
      @values = values
      @reasons = []
    end

    def call
      data = {
        employee_number: text("employee_number"), name: text("name"), department: text("department"), job_title: text("job_title"),
        country: code("country", 2), currency: code("currency", 3),
        hire_date: date("hire_date"), effective_from: date("effective_from"),
        base_pay: amount("base_pay"), gross: amount("gross"), net: amount("net"), deductions: deductions
      }
      check_frequency
      check_totals(data)
      check_dates(data)
      @reasons.empty? ? Result.new(data, []) : Result.new(nil, @reasons)
    end

    private

    def raw(column) = @values[column].to_s.strip

    def text(column)
      return raw(column) if raw(column).present?

      @reasons << "#{column} is missing"
      nil
    end

    def code(column, length)
      value = raw(column).upcase
      return value if value.match?(/\A[A-Z]{#{length}}\z/)

      @reasons << (value.empty? ? "#{column} is missing" : "#{column} must be a #{length}-letter code (got '#{raw(column)}')")
      nil
    end

    def date(column)
      return Date.iso8601(raw(column)) if raw(column).match?(/\A\d{4}-\d{2}-\d{2}\z/)

      @reasons << (raw(column).empty? ? "#{column} is missing" : "#{column} must be a date like 2024-01-31 (got '#{raw(column)}')")
      nil
    rescue Date::Error
      @reasons << "#{column} is not a real date (got '#{raw(column)}')"
      nil
    end

    def amount(column, source = raw(column))
      return BigDecimal(source) if source.match?(AMOUNT)

      @reasons << (source.empty? ? "#{column} is missing" : "#{column} must be a plain number with at most 2 decimals (got '#{source}')")
      nil
    end

    # "Income tax:100;Pension:50.5" -> [{label:, amount:}, ...]. An empty column means no deductions.
    def deductions
      return [] if raw("deductions").empty?

      raw("deductions").split(";").filter_map do |part|
        label, _, value = part.rpartition(":")
        if label.strip.empty?
          @reasons << "deductions must look like 'Income tax:100;Pension:50' (got '#{raw('deductions')}')"
          next
        end
        number = amount("deduction '#{label.strip}'", value.strip)
        { label: label.strip, amount: number } if number
      end
    end

    def check_frequency
      frequency = raw("frequency")
      @reasons << "only monthly pay is supported (got frequency '#{frequency}')" unless frequency.empty? || frequency.casecmp?("monthly")
    end

    def check_totals(data)
      return unless data[:gross] && data[:net] && @reasons.none? { |r| r.start_with?("deduction") }

      total = data[:deductions].sum { |d| d[:amount] }
      return if data[:gross] - total == data[:net]

      @reasons << "net (#{data[:net].to_s('F')}) does not equal gross (#{data[:gross].to_s('F')}) minus deductions (#{total.to_s('F')})"
    end

    def check_dates(data)
      return unless data[:hire_date] && data[:effective_from] && data[:effective_from] < data[:hire_date]

      @reasons << "effective_from (#{data[:effective_from]}) is before hire_date (#{data[:hire_date]})"
    end
  end
end
