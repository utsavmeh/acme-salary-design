module Reports
  # The highest paid employees (in a department, a country, or the whole company), ranked by
  # monthly base pay. In USD mode people whose currency has no rate for the year are left out of
  # the ranking and listed under missing_rates.
  class TopPaid < Base
    def call
      rows = current_rows
      conversion.ensure_single_currency!(rows.map { |r| r.record.currency })

      ranked = rows.filter_map do |row|
        amount = conversion.convert(row.record.base_pay, row.record.currency, as_of.year)
        [ row, amount ] if amount
      end
      top = ranked.sort_by { |row, amount| [ -amount, row.employee.employee_number ] }.first(limit)

      envelope(rows: top.each_with_index.map { |(row, amount), index| present(index + 1, row, amount) })
    end

    private

    def present(rank, row, amount)
      person(row.employee, row.assignment).merge(
        rank:, country: row.record.country, unit: conversion.unit(row.record.currency), base_pay: MoneyFormat.call(amount),
        original_currency: row.record.currency, original_base_pay: MoneyFormat.call(row.record.base_pay)
      )
    end
  end
end
