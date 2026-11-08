module Reports
  # Salary increases that took effect in a calendar year: who got them, old and new pay, and the
  # percentage. The percentage is worked out in the person's own currency, so exchange rates
  # never change it. Amounts in USD use the rate of that year for both old and new pay.
  # A change of currency is not comparable, so it is counted but not ranked.
  class Hikes < Base
    SORTS = %w[percent amount].freeze

    def call
      year = parse_year
      sort_by = params[:sort_by].presence || "percent"
      raise AppErrors::BadRequest, "sort_by must be one of #{SORTS.join(', ')}" unless SORTS.include?(sort_by)

      hikes, skipped = find_hikes(year)
      conversion.ensure_single_currency!(hikes.map { |h| h[:record].currency })
      rows = sort_by == "amount" ? rank_by_amount(hikes, year) : rank_by_percent(hikes, year)

      envelope(year:, sort_by:, skipped_currency_changes: skipped, rows:)
    end

    private

    def parse_year
      year = Integer(params[:year].to_s, 10)
      raise ArgumentError unless (1990..2200).cover?(year)

      year
    rescue ArgumentError
      raise AppErrors::BadRequest, "year is required, for example year=2025"
    end

    # Compares each effective salary record with the one before it for the same employee.
    def find_hikes(year)
      records = SalaryRecord.effective.where("salary_records.effective_from <= ?", Date.new(year, 12, 31))
                            .includes(employee: :assignments).order(:employee_id, :effective_from)
      hikes = []
      skipped = 0
      records.group_by(&:employee_id).each_value do |history|
        history.each_cons(2) do |previous, current|
          next unless current.effective_from.year == year && current.base_pay > previous.base_pay

          if previous.currency != current.currency || previous.base_pay.zero?
            skipped += 1
          else
            hikes << { previous:, record: current }
          end
        end
      end
      [ hikes, skipped ]
    end

    def rank_by_percent(hikes, year)
      top = hikes.sort_by { |h| [ -percent(h), h[:record].employee.employee_number ] }.first(limit)
      top.each_with_index.map { |h, i| present(i + 1, h, year) }
    end

    def rank_by_amount(hikes, year)
      converted = hikes.filter_map do |h|
        usd = conversion.convert(increase(h), h[:record].currency, year)
        [ h, usd ] if usd
      end
      top = converted.sort_by { |h, usd| [ -usd, h[:record].employee.employee_number ] }.first(limit)
      top.each_with_index.map { |(h, usd), i| present(i + 1, h, year, usd:) }
    end

    def present(rank, hike, year, usd: :not_converted_yet)
      record = hike[:record]
      usd = conversion.convert(increase(hike), record.currency, year) if usd == :not_converted_yet
      person(record.employee, record.employee.assignment_on(record.effective_from)).merge(
        rank:, effective_from: record.effective_from, currency: record.currency,
        old_base_pay: MoneyFormat.call(hike[:previous].base_pay), new_base_pay: MoneyFormat.call(record.base_pay),
        increase: MoneyFormat.call(increase(hike)), percent_increase: percent(hike).to_s("F"),
        increase_usd: conversion.usd? ? MoneyFormat.call(usd) : nil
      )
    end

    def increase(hike) = hike[:record].base_pay - hike[:previous].base_pay
    def percent(hike) = (increase(hike) / hike[:previous].base_pay * 100).round(2, BigDecimal::ROUND_HALF_UP)
  end
end
