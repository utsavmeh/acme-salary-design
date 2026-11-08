# The fixed USD rate of one currency for one calendar year (1 unit of currency = rate_to_usd USD).
#
# Rates are never overwritten. A change is a new row with the next version, a reason and the
# person who made it; the highest version is the one reports use.
class ExchangeRate < ApplicationRecord
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }, exclusion: { in: [ "USD" ], message: "USD is always 1 and cannot be set" }
  validates :year, numericality: { only_integer: true, greater_than_or_equal_to: 1990, less_than_or_equal_to: 2200 }
  validates :rate_to_usd, numericality: { greater_than: 0 }
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :reason, :set_by, presence: true

  before_destroy { throw :abort }
  def readonly? = persisted? || super

  scope :latest_versions, lambda {
    where(<<~SQL.squish)
      exchange_rates.version = (
        SELECT MAX(r.version) FROM exchange_rates r
        WHERE r.currency = exchange_rates.currency AND r.year = exchange_rates.year
      )
    SQL
  }

  # Stores a new rate (or a correction of an existing one) as the next version.
  def self.record!(currency:, year:, rate_to_usd:, reason:, set_by:)
    next_version = where(currency:, year:).maximum(:version).to_i + 1
    create!(currency:, year:, rate_to_usd:, version: next_version, reason:, set_by:)
  rescue ActiveRecord::RecordNotUnique
    raise AppErrors::Conflict, "Another change to #{currency} #{year} was saved first. Reload and try again."
  end
end
