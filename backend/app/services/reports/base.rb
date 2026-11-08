module Reports
  # Shared setup for all reports: parameters, the date the report is "as of", currency mode,
  # and the list of active employees with the salary and department in force on that date.
  class Base
    MODES = %w[usd native].freeze
    Row = Struct.new(:employee, :record, :assignment)

    def self.report_name = name.demodulize.underscore

    def initialize(params = {}, rate_book: RateBook.new, today: Date.current)
      @params = params.to_h.symbolize_keys
      @mode = @params[:currency_mode].presence || "usd"
      raise AppErrors::BadRequest, "currency_mode must be one of #{MODES.join(', ')}" unless MODES.include?(@mode)

      @as_of = parse_date(@params[:as_of]) || today
      @conversion = Conversion.new(mode: @mode, rate_book:)
    end

    private

    attr_reader :params, :as_of, :conversion

    def envelope(body)
      { report: self.class.report_name, as_of:, currency_mode: @mode, **body,
        missing_rates: conversion.missing, rates_used: conversion.rates_used }
    end

    # Active employees with their pay and department on `as_of`, narrowed by the optional filters.
    def current_rows
      records = SalaryRecord.current_as_of(as_of).joins(:employee).where(employees: { status: "active" })
                            .includes(employee: :assignments)
      rows = records.map { |record| Row.new(record.employee, record, record.employee.assignment_on(as_of)) }
      rows = rows.select { |r| r.assignment&.department == params[:department] } if params[:department].present?
      rows = rows.select { |r| r.assignment&.job_title == params[:job_title] } if params[:job_title].present?
      rows = rows.select { |r| r.record.country == params[:country].to_s.upcase } if params[:country].present?
      rows
    end

    def person(row_employee, assignment)
      { employee_id: row_employee.id, employee_number: row_employee.employee_number, name: row_employee.name,
        department: assignment&.department, job_title: assignment&.job_title }
    end

    def limit = params.fetch(:limit, 10).to_i.clamp(1, 100)

    def parse_date(value)
      return nil if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      raise AppErrors::BadRequest, "Dates must look like 2025-06-30"
    end
  end
end
