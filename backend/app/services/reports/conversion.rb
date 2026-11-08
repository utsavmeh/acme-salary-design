module Reports
  # Decides which amount a report shows and keeps track of what it needed.
  #
  # In "usd" mode an amount is converted with the rate of the given year. If that rate is missing
  # the amount is NOT shown (nil) and the gap is recorded so the report can list it. In "native"
  # mode amounts are left alone, which is only meaningful when everything is in one currency.
  class Conversion
    attr_reader :mode

    def initialize(mode:, rate_book:)
      @mode = mode
      @rate_book = rate_book
      @missing = Hash.new(0)
      @used = {}
    end

    def usd? = mode == "usd"

    def convert(amount, currency, year)
      return amount unless usd?

      rate = @rate_book.rate_for(currency, year)
      if rate.nil?
        @missing[[currency, year]] += 1
        return nil
      end
      @used[[currency, year]] = rate unless currency == "USD" # USD is always 1; not worth listing
      amount * rate
    end

    # Native-currency reports must not mix currencies, because adding INR to EUR means nothing.
    def ensure_single_currency!(currencies)
      return if usd?

      unique = currencies.uniq
      return if unique.size <= 1

      raise AppErrors::BadRequest, "A native-currency report needs a single currency but found #{unique.sort.join(', ')}. " \
                                   "Filter to one country or use currency_mode=usd."
    end

    def unit(native_currency) = usd? ? "USD" : native_currency

    def missing
      @missing.map { |(currency, year), count| { currency:, year:, amounts_affected: count } }.sort_by { |m| [m[:currency], m[:year]] }
    end

    def rates_used
      @used.map { |(currency, year), rate| { currency:, year:, rate_to_usd: rate.to_s("F") } }.sort_by { |r| [r[:currency], r[:year]] }
    end
  end
end
