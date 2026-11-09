# Times the main read paths on whatever data is loaded, so performance claims can be repeated.
#
#   bin/rails "seed:demo[10000]"     load dummy data first
#   bin/rails perf:reports
#
# Each case runs once to warm up, then three times; the median is printed with the number of SQL
# queries one run needs (a query count that grows with the data would mean an N+1 problem).
namespace :perf do
  desc "Time the reports, search, export and audit writes on the current data"
  task reports: :environment do
    abort "Refusing to run in production" if Rails.env.production?
    abort "No employees found. Load data first: bin/rails \"seed:demo[10000]\"" unless Employee.exists?

    clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }

    measure = lambda do |label, &block|
      block.call # warm-up: loads code and fills database caches
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
      times = Array.new(3) do
        queries = 0
        started = clock.call
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { block.call }
        ((clock.call - started) * 1000).round
      end
      puts format("%-46s %7d ms %8d queries", label, times.sort[1], queries)
    end

    puts "Data: #{Employee.count} employees, #{SalaryRecord.count} salary records, #{DeductionLine.count} deduction lines, " \
         "#{ExchangeRate.count} exchange rates, #{AuditEvent.count} audit events"
    puts "Environment: #{Rails.env}, #{ActiveRecord::Base.connection.select_value('SHOW server_version')} PostgreSQL, Ruby #{RUBY_VERSION}"
    puts "-" * 70

    last_year = Date.current.year - 1
    measure.call("Report: pay summary by department (USD)") { Reports::PaySummary.new({}).call }
    measure.call("Report: pay summary by country (USD)") { Reports::PaySummary.new({ group_by: "country" }).call }
    measure.call("Report: top 10 highest paid (USD)") { Reports::TopPaid.new({}).call }
    measure.call("Report: biggest hikes #{last_year} (by percent)") { Reports::Hikes.new({ year: last_year }).call }
    measure.call("Report: biggest hikes #{last_year} (by USD amount)") { Reports::Hikes.new({ year: last_year, sort_by: "amount" }).call }
    measure.call("Report: data quality") { Reports::DataQuality.new({}).call }
    measure.call("Search: name text, first 25 rows") { EmployeeSearch.new({ q: "an" }).call.includes(:assignments).limit(25).to_a }
    measure.call("Search: department filter, first 25 rows") { EmployeeSearch.new({ department: "Engineering" }).call.includes(:assignments).limit(25).to_a }
    measure.call("CSV export of every employee") do
      employees = EmployeeSearch.new({}).call.includes(:assignments).to_a
      EmployeeCsv.new(employees, SalaryRecord.current_by_employee(employees.map(&:id))).call
    end

    # Audit writes take a lock so the hash chain has no forks; measure 100 writes, then roll them back.
    ActiveRecord::Base.transaction do
      started = clock.call
      100.times { |i| AuditLog.record(actor: "perf", action: "perf.probe", details: { i: }) }
      puts format("%-46s %7.1f ms per event", "Audit log write (100 events, rolled back)", (clock.call - started) * 10)
      raise ActiveRecord::Rollback
    end
  end
end
