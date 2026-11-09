# Fills the database with dummy data for trying the app out. Development and test only, unless
# ALLOW_DEMO_SEED=yes is set (for a demo deployment that holds no real salaries).
#
#   bin/rails "seed:demo[10000]"      employees to create (default 10000)
#   SEED=7 bin/rails seed:demo        a different (but still repeatable) random data set
#
# The data is made up. It is repeatable: the same SEED always gives the same data.
# It only runs on an empty employee table; to start over: bin/rails db:schema:load
namespace :seed do
  desc "Create dummy employees, department history, salary history, deductions and exchange rates"
  task :demo, %i[count] => :environment do |_t, args|
    abort "Refusing to load dummy data in production (set ALLOW_DEMO_SEED=yes to override on a demo deployment)" if Rails.env.production? && ENV["ALLOW_DEMO_SEED"] != "yes"
    abort "Employees already exist. To start over run: bin/rails db:schema:load" if Employee.exists?

    count = Integer(args[:count] || 10_000)
    abort "count must be at least 1" if count < 1
    rng = Random.new(Integer(ENV.fetch("SEED", 42)))
    today = Date.current
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # ---- Reference data -------------------------------------------------------------------
    # country => [currency, share of staff, pay level vs the US, income tax rate, pension rate]
    countries = {
      "US" => [ "USD", 30, 1.00, "0.22", "0.05" ], "GB" => [ "GBP", 10, 0.80, "0.24", "0.05" ],
      "DE" => [ "EUR", 9, 0.85, "0.30", "0.09" ],  "FR" => [ "EUR", 6, 0.80, "0.28", "0.08" ],
      "IN" => [ "INR", 22, 0.25, "0.15", "0.12" ], "JP" => [ "JPY", 5, 0.70, "0.20", "0.09" ],
      "BR" => [ "BRL", 5, 0.35, "0.20", "0.08" ],  "CA" => [ "CAD", 5, 0.90, "0.24", "0.05" ],
      "AU" => [ "AUD", 4, 0.95, "0.25", "0.10" ],  "SG" => [ "SGD", 4, 0.90, "0.12", "0.17" ]
    }.freeze
    # currency => [USD value of 1 unit in the first year, yearly change]
    rate_start = {
      "USD" => nil, "GBP" => [ 1.28, -0.010 ], "EUR" => [ 1.11, -0.004 ], "INR" => [ 0.0152, -0.025 ], "JPY" => [ 0.0083, -0.045 ],
      "BRL" => [ 0.30, -0.060 ], "CAD" => [ 0.78, -0.006 ], "AUD" => [ 0.74, -0.008 ], "SGD" => [ 0.72, 0.004 ]
    }.freeze
    first_year = today.year - 11
    # department => [monthly base pay in USD at the lowest level, job titles from junior to senior]
    departments = {
      "Engineering" => [ 4500, [ "Software Engineer", "Senior Software Engineer", "Staff Engineer", "Engineering Manager" ] ],
      "Product" => [ 4800, [ "Associate Product Manager", "Product Manager", "Senior Product Manager", "Director of Product" ] ],
      "Sales" => [ 3500, [ "Sales Representative", "Account Executive", "Senior Account Executive", "Sales Manager" ] ],
      "Marketing" => [ 3300, [ "Marketing Associate", "Marketing Specialist", "Senior Marketer", "Marketing Manager" ] ],
      "Human Resources" => [ 3000, [ "HR Coordinator", "HR Generalist", "Senior HR Partner", "HR Manager" ] ],
      "Finance" => [ 3600, [ "Accountant", "Senior Accountant", "Finance Analyst", "Finance Manager" ] ],
      "Operations" => [ 2800, [ "Operations Associate", "Operations Specialist", "Senior Operations Specialist", "Operations Manager" ] ],
      "Support" => [ 2200, [ "Support Agent", "Senior Support Agent", "Support Lead", "Support Manager" ] ],
      "Legal" => [ 5000, [ "Legal Assistant", "Legal Counsel", "Senior Counsel", "General Counsel" ] ]
    }.freeze
    department_weights = { "Engineering" => 30, "Product" => 6, "Sales" => 20, "Marketing" => 8, "Human Resources" => 4,
                           "Finance" => 7, "Operations" => 12, "Support" => 11, "Legal" => 2 }.freeze
    level_multiplier = [ 1.0, 1.35, 1.8, 2.4 ].freeze
    level_weights = [ 45, 30, 18, 7 ].freeze
    first_names = %w[Aarav Aisha Akira Alejandro Amelia Ana Andre Anya Ben Carlos Chen Chloe Daniel Diego Elena Emma Eva Farid Fatima
                     Grace Hana Hiro Ibrahim Isabella Jack Jin Julia Kenji Layla Liam Lucas Maria Mei Mohammed Nadia Noah Olivia Omar
                     Priya Rahul Ravi Sara Sofia Takeshi Wei Yara Zoe].freeze
    last_names = %w[Adams Ali Anderson Banerjee Bauer Brown Chen Clark Costa Das Davis Dubois Evans Fernandez Garcia Gupta Hall
                    Hughes Ito Jackson Johnson Kapoor Kim Kumar Lee Lopez Martin Mehta Miller Moreau Murphy Nakamura Nguyen Novak
                    Patel Perez Reddy Rossi Sato Schmidt Sharma Silva Singh Smith Tan Taylor Tanaka Walker Wilson Wong Young].freeze
    gaps = [ 5, count / 10 ].min # active employees left without a salary record, so the data-quality report has something to show

    pick = lambda do |weighted|
      roll = rng.rand(weighted.values.sum)
      weighted.each { |key, weight| (roll -= weight).negative? ? (return key) : nil }
    end
    pick_index = ->(weights) { pick.call(weights.each_with_index.to_h { |w, i| [ i, w ] }) }
    money = ->(value) { BigDecimal(value.to_s).round(2, BigDecimal::ROUND_HALF_UP) }
    # Pay is rounded to a "nice" amount in each currency (e.g. whole thousands of yen).
    nice = ->(amount, currency) { step = { "JPY" => 1000, "INR" => 500, "BRL" => 100 }.fetch(currency, 50); ((amount / step).round * step).to_i }

    # ---- Exchange rates (one per currency per calendar year) ------------------------------------
    rates = Hash.new { |hash, key| hash[key] = {} }
    rate_start.each do |currency, start|
      (first_year..today.year).each do |year|
        rates[currency][year] = start ? (start[0] * ((1 + start[1])**(year - first_year))).round(6) : 1.0
      end
    end

    # ---- Build one employee: details, department history, salary history ------------------------
    build_employee = lambda do |index|
      country = pick.call(countries.transform_values { |c| c[1] })
      currency, _share, level, tax_rate, pension_rate = countries[country]
      department = pick.call(department_weights)
      base_usd, titles = departments[department]
      title_level = pick_index.call(level_weights)

      hire_date = Date.new(first_year, 1, 1) + rng.rand((today - Date.new(first_year, 1, 1)).to_i - 30)
      left_on = rng.rand < 0.06 ? hire_date + 180 + rng.rand(((today - hire_date).to_i - 180).clamp(1, 4000)) : nil
      left_on = nil if left_on && left_on >= today
      end_date = left_on || today

      usd_pay = base_usd * level_multiplier[title_level] * level * rng.rand(0.85..1.15)
      pay = nice.call(usd_pay / rates[currency][hire_date.year], currency)

      assignments = [ { department:, job_title: titles[title_level], effective_from: hire_date } ]
      raises = [ { effective_from: hire_date, base_pay: pay } ]
      review_month = [ 1, 4, 7 ].fetch(rng.rand(3))
      (hire_date.year + 1..end_date.year).each do |year|
        review = Date.new(year, review_month, 1)
        next if review > end_date || rng.rand > 0.88

        promoted = title_level < titles.size - 1 && rng.rand < 0.10
        percent = promoted ? rng.rand(15.0..30.0) : rng.rand(3.0..12.0)
        pay = nice.call(pay * (1 + (percent / 100.0)), currency)
        raises << { effective_from: review, base_pay: pay }
        next unless promoted

        title_level += 1
        assignments << { department:, job_title: titles[title_level], effective_from: review }
      end
      raises = [] if index < gaps # the few employees without any salary record

      records = raises.map do |raise_entry|
        gross = money.call(raise_entry[:base_pay])
        lines = [ [ "Income tax", money.call(gross * BigDecimal(tax_rate)) ], [ "Pension", money.call(gross * BigDecimal(pension_rate)) ] ]
        lines << [ "Health insurance", money.call(gross * BigDecimal("0.02")) ] if rng.rand < 0.5
        { effective_from: raise_entry[:effective_from], currency:, country:, base_pay: gross, gross:,
          net: gross - lines.sum { |_label, amount| amount }, lines: }
      end

      employee = { employee_number: format("D%05d", index + 1), name: "#{first_names.sample(random: rng)} #{last_names.sample(random: rng)}",
                   country:, hire_date:, status: left_on ? "inactive" : "active" }
      { employee:, assignments:, records: }
    end

    # ---- Write everything, in batches, in one transaction ------------------------------------
    totals = Hash.new(0)
    ActiveRecord::Base.transaction do
      rates.each do |currency, by_year|
        next if currency == "USD"

        by_year.each do |year, rate|
          ExchangeRate.record!(currency:, year:, rate_to_usd: rate, reason: "Demo data", set_by: "seed")
          totals[:rates] += 1
        end
      end

      (0...count).each_slice(500) do |indexes|
        plans = indexes.map(&build_employee)
        ids = Employee.insert_all!(plans.map { |p| p[:employee] }, returning: %w[id employee_number]).rows.to_h { |id, number| [ number, id ] }

        assignment_rows = plans.flat_map { |p| p[:assignments].map { |a| a.merge(employee_id: ids.fetch(p[:employee][:employee_number])) } }
        Assignment.insert_all!(assignment_rows)

        record_rows = plans.flat_map do |p|
          employee_id = ids.fetch(p[:employee][:employee_number])
          p[:records].map { |r| r.except(:lines).merge(employee_id:, version: 1, created_by: "seed") }
        end
        saved = record_rows.empty? ? [] : SalaryRecord.insert_all!(record_rows, returning: %w[id employee_id effective_from]).rows
        id_of = saved.to_h { |id, employee_id, date| [ [ employee_id, date.to_s ], id ] }

        line_rows = plans.flat_map do |p|
          employee_id = ids.fetch(p[:employee][:employee_number])
          p[:records].flat_map do |r|
            salary_record_id = id_of.fetch([ employee_id, r[:effective_from].to_s ])
            r[:lines].map { |label, amount| { salary_record_id:, label:, amount: } }
          end
        end
        DeductionLine.insert_all!(line_rows) if line_rows.any?

        totals[:employees] += plans.size
        totals[:assignments] += assignment_rows.size
        totals[:salary_records] += record_rows.size
        totals[:deduction_lines] += line_rows.size
        print "\r#{totals[:employees]} / #{count} employees"
      end

      AuditLog.record(actor: "seed", action: "seed.demo_data_loaded", details: totals.merge(seed: ENV.fetch("SEED", 42).to_i))
    end

    seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(1)
    puts "\nLoaded in #{seconds}s: #{totals.map { |k, v| "#{v} #{k.to_s.tr('_', ' ')}" }.join(', ')}"
    puts "#{Employee.where(status: 'inactive').count} employees have left (inactive); #{gaps} active employees have no salary record on purpose."
  end
end
