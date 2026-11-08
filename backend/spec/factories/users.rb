FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user#{n}" }
    password { "correct horse battery" }
    roles { ["hr"] }
    status { "active" }
    must_change_password { false }
  end
end
