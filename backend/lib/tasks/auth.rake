namespace :auth do
  desc "Print a development sign-in token. Usage: rails 'auth:dev_token[me@acme.test,salary-hr salary-rate-manager]'"
  task :dev_token, %i[email groups] => :environment do |_task, args|
    abort "Refusing to create tokens in production" if Rails.env.production?

    payload = {
      email: args[:email] || "hr@acme.test",
      groups: (args[:groups] || "salary-hr").split,
      exp: 12.hours.from_now.to_i
    }
    puts JWT.encode(payload, Rails.configuration.x.auth.jwt_secret, Auth::TokenVerifier::ALGORITHM)
  end
end
