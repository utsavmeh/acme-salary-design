FactoryBot.define do
  factory :exchange_rate do
    currency { "INR" }
    year { 2024 }
    rate_to_usd { "0.012" }
    version { 1 }
    reason { "Annual rate" }
    set_by { "rates@acme.test" }
  end
end
