module Imports
  # Totals per currency so HR can compare them with the original Excel (for example its SUM row):
  #   file     = every row in the uploaded file whose amounts could be read
  #   accepted = rows that passed checks;  rejected = rows that did not
  #   loaded   = what is really in the salary tables for this import (after commit)
  # `file` must equal `accepted + rejected`, and after commit `loaded` must equal `accepted`.
  class Reconciliation
    UNKNOWN = "(unknown)".freeze

    def self.call(batch) = new(batch).call

    def initialize(batch)
      @batch = batch
    end

    def call
      rows = @batch.import_rows.to_a
      currencies = (rows.map { |r| currency_of(r) } + loaded.keys).uniq.sort
      lines = currencies.map { |currency| line(currency, rows.select { |r| currency_of(r) == currency }) }

      {
        import_id: @batch.id, status: @batch.status, filename: @batch.filename,
        rows: { in_file: rows.size, accepted: @batch.accepted_rows, rejected: @batch.rejected_rows },
        currencies: lines,
        balanced: lines.all? { |l| l[:file_equals_accepted_plus_rejected] } && rows.size == @batch.accepted_rows + @batch.rejected_rows,
        loaded_matches_accepted: @batch.committed? ? lines.all? { |l| l[:loaded_matches_accepted] } : nil
      }
    end

    private

    def line(currency, rows)
      accepted = rows.select { |r| r.status == "accepted" }
      rejected = rows.select { |r| r.status == "rejected" }
      file = totals(rows)
      accepted_totals = totals(accepted)
      rejected_totals = totals(rejected)
      loaded_totals = loaded[currency] || { rows: 0, gross: 0, net: 0 }

      {
        currency:,
        file: present_totals(file), accepted: present_totals(accepted_totals), rejected: present_totals(rejected_totals),
        loaded: @batch.committed? ? present_totals(loaded_totals) : nil,
        unreadable_amount_rows: rows.count { |r| amount(r, "gross").nil? || amount(r, "net").nil? },
        file_equals_accepted_plus_rejected: file[:gross] == accepted_totals[:gross] + rejected_totals[:gross] &&
                                            file[:net] == accepted_totals[:net] + rejected_totals[:net],
        loaded_matches_accepted: @batch.committed? ? loaded_totals == accepted_totals : nil
      }
    end

    def totals(rows)
      { rows: rows.size, gross: rows.sum { |r| amount(r, "gross") || 0 }, net: rows.sum { |r| amount(r, "net") || 0 } }
    end

    def present_totals(totals) = { rows: totals[:rows], gross: MoneyFormat.call(totals[:gross]), net: MoneyFormat.call(totals[:net]) }

    # Amounts of rows that were actually loaded, by currency.
    def loaded
      @loaded ||= @batch.salary_records.group(:currency).pluck(:currency, Arel.sql("COUNT(*)"), Arel.sql("SUM(gross)"), Arel.sql("SUM(net)"))
                        .to_h { |currency, count, gross, net| [ currency, { rows: count, gross:, net: } ] }
    end

    def currency_of(row)
      row.raw["currency"].to_s.strip.upcase.presence || UNKNOWN
    end

    def amount(row, column)
      value = row.raw[column].to_s.strip
      value.match?(RowValidator::AMOUNT) ? BigDecimal(value) : nil
    end
  end
end
