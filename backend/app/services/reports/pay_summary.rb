module Reports
  # Headcount and monthly base pay (total, average, lowest, highest) per department, country,
  # job title, or for everyone. USD mode also shows the original amounts per currency.
  class PaySummary < Base
    GROUPERS = {
      "department" => ->(row) { row.assignment&.department || "(no department)" },
      "country" => ->(row) { row.record.country },
      "job_title" => ->(row) { row.assignment&.job_title || "(no job title)" },
      "none" => ->(_row) { "All employees" }
    }.freeze

    def call
      group_by = params[:group_by].presence || "department"
      grouper = GROUPERS.fetch(group_by) { raise AppErrors::BadRequest, "group_by must be one of #{GROUPERS.keys.join(', ')}" }
      rows = current_rows
      conversion.ensure_single_currency!(rows.map { |r| r.record.currency })

      groups = rows.group_by(&grouper).sort_by { |name, _| name }.map { |name, members| summarize(name, members) }
      envelope(group_by:, groups:)
    end

    private

    def summarize(name, members)
      values = members.filter_map { |r| conversion.convert(r.record.base_pay, r.record.currency, as_of.year) }
      {
        group: name, headcount: members.size, counted: values.size, excluded_for_missing_rate: members.size - values.size,
        unit: conversion.unit(members.first.record.currency),
        total: format_money(values.sum), average: format_money(values.empty? ? nil : values.sum / values.size),
        lowest: format_money(values.min), highest: format_money(values.max),
        original_amounts: original_amounts(members)
      }
    end

    def original_amounts(members)
      members.group_by { |r| r.record.currency }.sort.map do |currency, rows|
        { currency:, headcount: rows.size, total_base_pay: MoneyFormat.call(rows.sum { |r| r.record.base_pay }) }
      end
    end

    def format_money(value) = MoneyFormat.call(value)
  end
end
