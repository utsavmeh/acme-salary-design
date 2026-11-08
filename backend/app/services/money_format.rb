# Money is sent as a string with exactly two decimals ("1000.50"), never as a float.
module MoneyFormat
  module_function

  def call(value)
    return nil if value.nil?

    whole, fraction = value.to_d.round(2, BigDecimal::ROUND_HALF_UP).to_s("F").split(".")
    "#{whole}.#{fraction.to_s.ljust(2, '0')}"
  end
end
