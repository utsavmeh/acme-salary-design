# Account management for operators. There is no admin role or screen in the web app.
#
#   bin/rails "users:create[asha.rao,hr rate_manager]"   roles: hr, rate_manager, auditor (space separated)
#   bin/rails "users:set_roles[asha.rao,hr]"
#   bin/rails "users:reset_password[asha.rao]"
#   bin/rails "users:deactivate[asha.rao]"  /  users:activate  /  users:unlock
#   bin/rails users:list
namespace :users do
  manager = -> { Users::Manager.new(operator: ENV.fetch("USER", "unknown")) }

  # Prints a clear message instead of a stack trace for expected problems.
  run = lambda do |&block|
    block.call
  rescue AppErrors::BadRequest, ActiveRecord::RecordInvalid => e
    abort "Failed: #{e.respond_to?(:record) ? e.record.errors.full_messages.to_sentence : e.message}"
  end

  desc "Create a user with a one-time password"
  task :create, %i[username roles] => :environment do |_t, args|
    run.call do
      created = manager.call.create(username: args[:username], roles: args[:roles].to_s.split)
      puts "Created #{created.user.username} (roles: #{created.user.roles.join(', ').presence || 'none'})"
      puts "One-time password (shown once, must be changed at first sign-in): #{created.temporary_password}"
    end
  end

  desc "Replace a user's roles"
  task :set_roles, %i[username roles] => :environment do |_t, args|
    run.call { puts "#{args[:username]} now has roles: #{manager.call.set_roles(args[:username], args[:roles].to_s.split).roles.join(', ').presence || 'none'}" }
  end

  desc "Give a user a new one-time password"
  task :reset_password, %i[username] => :environment do |_t, args|
    run.call do
      reset = manager.call.reset_password(args[:username])
      puts "One-time password for #{reset.user.username} (shown once): #{reset.temporary_password}"
    end
  end

  desc "Deactivate a user (they can no longer sign in; the account is kept for the audit trail)"
  task :deactivate, %i[username] => :environment do |_t, args|
    run.call { puts "#{manager.call.deactivate(args[:username]).username} is deactivated" }
  end

  desc "Reactivate a user"
  task :activate, %i[username] => :environment do |_t, args|
    run.call { puts "#{manager.call.activate(args[:username]).username} is active" }
  end

  desc "Clear a login lockout"
  task :unlock, %i[username] => :environment do |_t, args|
    run.call { puts "#{manager.call.unlock(args[:username]).username} is unlocked" }
  end

  desc "List users"
  task list: :environment do
    manager.call.list.each do |u|
      puts format("%-30s %-12s %-30s %s", u.username, u.status, u.roles.join(","), u.locked? ? "LOCKED" : "")
    end
  end
end
