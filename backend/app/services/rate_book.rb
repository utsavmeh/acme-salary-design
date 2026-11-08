# Looks up the rate to use for (currency, year) and converts amounts to USD.
#
# Loads the latest version of every rate once, so a report does not hit the database per row.
# A missing rate gives nil: callers must report it, never guess or fall back to another year.
class RateBook
  def initialize(rates = ExchangeRate.latest_versions)
    @rates = rates.to_h { |r| [[r.currency, r.year], r.rate_to_usd] }
  end

  def rate_for(currency, year)
    return BigDecimal("1") if currency == "USD"

    @rates[[currency, year]]
  end

  # Unrounded USD value, or nil when the rate for that currency and year is missing.
  def to_usd(amount, currency, year)
    rate = rate_for(currency, year)
    rate && amount * rate
  end
end
