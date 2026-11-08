require "csv"
require "tempfile"

# Builds small CSV files for import specs, so each spec shows the rows it cares about.
module ImportHelpers
  HEADERS = %w[employee_number name country hire_date department job_title currency base_pay gross deductions net effective_from].freeze

  def import_row(overrides = {})
    {
      "employee_number" => "E1", "name" => "Asha Rao", "country" => "IN", "hire_date" => "2020-01-01",
      "department" => "Engineering", "job_title" => "Developer", "currency" => "INR",
      "base_pay" => "1000", "gross" => "1000", "deductions" => "Income tax:150", "net" => "850",
      "effective_from" => "2024-01-01"
    }.merge(overrides)
  end

  # Writes the rows to a temp .csv file and returns its path.
  def csv_path(rows, headers: HEADERS)
    @csv_files ||= []
    file = Tempfile.new([ "import", ".csv" ])
    file.write(CSV.generate { |csv| csv << headers; rows.each { |r| csv << headers.map { |h| r[h] } } })
    file.close
    @csv_files << file
    file.path
  end

  def stage(rows, uploaded_by: "hr@acme.test", headers: HEADERS)
    Imports::Stage.call(path: csv_path(rows, headers:), filename: "salaries.csv", uploaded_by:)
  end

  def uploaded_csv(rows) = Rack::Test::UploadedFile.new(csv_path(rows), "text/csv")
end

RSpec.configure { |config| config.include ImportHelpers }
